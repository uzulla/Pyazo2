package Pyazo2::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Amon2::Web::Dispatcher::RouterBoom;

use File::Slurp;
use Time::HiRes qw/ time /;
use String::Random;
use File::Basename;
use Image::Info;
use File::Path;
use Media::Type::Simple;
use LWP::UserAgent;
use Data::Dumper;
use Path::Tiny;
use File::Temp qw/ tempfile tempdir /;
use feature 'say';
use Imager;
use Imager::Filter::ExifOrientation;

get '/' => sub {
    my ($c) = @_;

    my $gifzo_support = (
      $c->config->{external_commands}->{ffmpeg_path} &&
      (
        $c->config->{external_commands}->{gifsicle_path} ||
        $c->config->{external_commands}->{imagemagick_convert_path}
      )
    );

    return $c->render('index.tx' => +{
      host_info => +{
        hostname => $c->req->uri->host,
        port => 5000
      },
      support => +{
        gifzo => $gifzo_support
      }
    });
};

post '/' => sub {
    my ($c) = @_;

    my $filename;
    my $upload;
    my $_uploads = $c->req->uploads;
    my $MAX_PX = $c->config->{settings}->{auto_resize_max_px};

    if($_uploads->{'imagedata'}){ #pyazo mode
        $upload = $_uploads->{'imagedata'};
        my ($fn, $path, $type) = fileparse( $upload->{filename}, qr/\.[^\.]+$/ );
        if( !$type || $type eq '.com' ){ # .com will pass by mac gyazo client. wtf???
            my $img_info = Image::Info::image_type($upload->{tempname}); #画像データの一部から判定
            if ( $img_info->{error} ) {
                $c->create_simple_status_page('500', sprintf("Can't determine file type: %s", $img_info->{error})) ;
            }
            $type = '.'.$img_info->{file_type};
        }
        
        $type = lc($type);

        $filename = "image/" . Pyazo2::randstr().$type;
        my $dist_path = path($c->base_dir.'/'.$filename)->realpath;
        path($upload->path)->move($dist_path);

        # fix jpeg orientation
        if($type eq '.jpg' || $type eq '.jpeg'){ 
            my $img = Imager->new;
            $img->read( file => $dist_path, type=>'jpeg' ) or die $img->errstr;
            $img->filter( type => 'exif_orientation' ) or die $img->errstr;
            $img->write( file => $dist_path, type=>'jpeg' ) or die $img->errstr;
        }

        # auto resize
        if(
            $c->req->param('auto_resize') &&
            $c->req->param('auto_resize') eq "1" &&
            ($type eq '.jpg' || $type eq '.jpeg' || $type eq '.gif' || $type eq '.png')
        ){ 
            my $width;
            my $height;
            if($c->req->param('auto_resize_for') eq 'yancha_avatar'){
                $width = 48;
                $height = 48;
            }else{
                $width = $c->req->param('width') // $MAX_PX;
                $height = $c->req->param('height') // $MAX_PX;
            }
            my $img = Imager->new;
            $img->read( file => $dist_path ) or die $img->errstr;
            my $x = $img->getwidth();
            my $y = $img->getheight();
            if($x>$width || $y>$height){
                $img = $img->scale(
                    xpixels => $width,
                    ypixels => $height,
                    type    => 'min',
                ) or die $img->errstr;
                $img->write( file => $dist_path ) or die $img->errstr;
            }
        }

        chmod 0666, $dist_path;
    }elsif($_uploads->{'data'}){ #gifzo mode
        my $FFMPEG_PATH = $c->config->{external_commands}->{ffmpeg_path};
        my $GIFSICLE_PATH = $c->config->{external_commands}->{gifsicle_path};
        my $CONVERT_PATH = $c->config->{external_commands}->{imagemagick_convert_path};
        my $USE_GIF = $c->config->{settings}->{force_use_gif_in_temporary};
        my $FPS = $c->config->{settings}->{frame_rate};
        my $FRAME_DELAY = $c->config->{settings}->{frame_delay};
        my $EXTRA_FFMPEG_OPT = $c->config->{settings}->{extra_ffmpeg_opt};

        $c->create_simple_status_page('500', "require FFMPEG_PATH in config") unless $FFMPEG_PATH;
        $c->create_simple_status_page('500', "require IM_CONVERT_PATH or GIFSICLE_PATH in config") unless(
            $CONVERT_PATH ||
            $GIFSICLE_PATH);

        my $temporary_format;
        if( $GIFSICLE_PATH || $USE_GIF ){
            $temporary_format = 'gif'; # fast, compact filesize. but bit dirty.(dithering)
        }else{
            $temporary_format = 'png'; # slow(5 to 10 times), large filesize(about twice). but bit clear.
        }

        $upload = $_uploads->{'data'};
        my $tmpdirpath = tempdir( CLEANUP => 1 );

        my $movfilename = $upload->tempname;

        my $execline = "${FFMPEG_PATH} -i $movfilename -r $FPS $EXTRA_FFMPEG_OPT -f image2 $tmpdirpath/%05d.$temporary_format";
        say $execline;
        `$execline`;

        my $outgif = "$tmpdirpath/out.gif";
        my $execline2;
        if($GIFSICLE_PATH){
            $execline2 = "$GIFSICLE_PATH --delay=$FRAME_DELAY --loop $tmpdirpath/*.$temporary_format > $outgif";
        }elsif($CONVERT_PATH){
            $execline2 = "$CONVERT_PATH $tmpdirpath/*.$temporary_format $outgif";
        }else{
            $c->create_simple_status_page('500', "require imagemagick_convert_path or ffmpeg_path in config");
        }
        say $execline2;
        `$execline2`;

        my $randstr = Pyazo2::randstr();
        my $giffilename = "image/" . $randstr . ".gif";
        path($outgif)->move($c->base_dir.'/' . $giffilename);
        my $mp4filename = "image/" . $randstr . ".mp4";
        path($upload->path)->move($c->base_dir.'/' . $mp4filename);
        chmod 0666, $c->base_dir.'/' . $giffilename;
        chmod 0666, $c->base_dir.'/' . $mp4filename;
        $filename = $giffilename;
    }elsif( $c->req->param('fileurl') ){
        my $url = $c->req->param('fileurl');
        my $ua = LWP::UserAgent->new;
        my $r = $ua->head( $url );

        return $c->create_simple_status_page('500', 'error: HEAD request fail') unless $r;

        my $size = $r->header('Content-Length');

        if( !$size || $size > (5*1024*1024) ){
            return $c->create_simple_status_page('500', 'error: request url too big (or get fail Content-Length)') ;
        }

        my $content_type = $r->header('Content-Type');
        my $type = ext_from_type($content_type);
        $type = ".$type" if $type;

        if(!$type){
            my $_url = $url;
            $_url =~ s/#.*$//;
            $_url =~ s/^.*\///;
            my ($fn, $path, $_type) = fileparse( $_url, qr/\.[^\.]+$/ );
            $type = $_type;
        }

        $filename = Pyazo2::randstr().$type;

        $url = $c->req->param('fileurl');
        my $dist_path = path($c->base_dir.'/image/'. $filename)->realpath;
        $r = $ua->mirror($url, $dist_path);
        
        return $c->create_simple_status_page('500', 'error: get fail') unless $r;
        $filename = 'image/'.$filename;
        
        # fix jpeg orientation
        if(lc($type) eq '.jpg' || lc($type) eq '.jpeg'){ 
            my $img = Imager->new;
            $img->read( file => $dist_path, type=>'jpeg' ) or die $img->errstr;
            $img->filter( type => 'exif_orientation' ) or die $img->errstr;
            $img->write( file => $dist_path, type=>'jpeg' ) or die $img->errstr;
        }
        
        # auto resize
        if(
            $c->req->param('auto_resize') eq "1" &&
            ($type eq '.jpg' || $type eq '.jpeg' || $type eq '.gif' || $type eq '.png')
        ){ 
            my $width;
            my $height;
            if($c->req->param('auto_resize_for') eq 'yancha_avatar'){
                $width = 48;
                $height = 48;
            }else{
                $width = $c->req->param('width') // $MAX_PX;
                $height = $c->req->param('height') // $MAX_PX;
            }
            my $img = Imager->new;
            $img->read( file => $dist_path ) or die $img->errstr;
            my $x = $img->getwidth();
            my $y = $img->getheight();
            if($x>$width || $y>$height){
                $img = $img->scale(
                    xpixels => $width,
                    ypixels => $height,
                    type    => 'min',
                ) or die $img->errstr;
                $img->write( file => $dist_path ) or die $img->errstr;
            }
        }

        chmod 0666, $dist_path;
    }
    return $c->create_simple_status_page('500', 'error: blank post') unless $filename;
    return $c->create_response(200, ['Content-Type' => 'text/plain'], [$c->req->base().$filename]);

};

1;
