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

get '/' => sub {
    my ($c) = @_;
    return $c->render('index.tx');
};

post '/' => sub {
    my ($c) = @_;

    my $filename;
    my $upload;
    my $_uploads = $c->req->uploads;

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
        $filename = "image/" . Pyazo2::randstr() . lc($type);

        path($upload->path)->move($c->base_dir.'/'.$filename);

    }elsif($_uploads->{'data'}){ #gifzo mode
        my $FFMPEG_PATH = $c->config->{external_commands}->{ffmpeg_path};
        my $GIFSICLE_PATH = $c->config->{external_commands}->{gifsicle_path};
        my $CONVERT_PATH = $c->config->{external_commands}->{imagemagick_convert_path};
        my $USE_GIF = $c->config->{settings}->{force_use_gif_in_temporary};
        my $FPS = $c->config->{settings}->{frame_rate};
        my $FRAME_DELAY = $c->config->{settings}->{frame_delay};

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

        my $execline = "${FFMPEG_PATH} -i $movfilename -r $FPS $tmpdirpath/%05d.$temporary_format";
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
        my $ext = ext_from_type($content_type);
        $ext = ".$ext" if $ext;

        if(!$ext){
            my $_url = $url;
            $_url =~ s/#.*$//;
            $_url =~ s/^.*\///;
            my ($fn, $path, $type) = fileparse( $_url, qr/\.[^\.]+$/ );
            $ext = $type;
        }

        $filename = Pyazo2::randstr() . $ext;

        $url = $c->req->param('fileurl');
        $r = $ua->mirror($url, $c->base_dir.'/image/'. $filename);
        return $c->create_simple_status_page('500', 'error: get fail') unless $r;

        $filename = 'image/'.$filename;
    }
    return $c->create_simple_status_page('500', 'error: blank post') unless $filename;
    return $c->create_response(200, ['Content-Type' => 'text/plain'], [$c->req->base().$filename]);

};

1;
