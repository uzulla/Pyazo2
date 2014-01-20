use File::Spec;
use File::Basename qw(dirname);
my $basedir = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..'));
my $dbpath = File::Spec->catfile($basedir, 'db', 'development.db');
+{
    'DBI' => [
        "dbi:SQLite:dbname=$dbpath", '', '',
        +{
            sqlite_unicode => 1,
        }
    ],
    'external_commands' => +{
        "ffmpeg_path" => "/usr/local/bin/ffmpeg",
        "imagemagick_convert_path" => "/usr/local/bin/convert",
        "gifsicle_path" => undef,
    },
    'settings' => +{
        "force_use_gif_in_temporary" => 0,
        "frame_rate" => 3,
        "frame_delay" => 10,
        "allow_cross_site_domain" => "*",
        "auto_resize_max_px" => 1200,
        # this is magic for gif_temporary (force_use_gif_in_temporary or use gifsicle) ffmpeg broken gif. old ffmpeg is not support -vf. (tested by 1.2.6)
        # "extra_ffmpeg_opt" => " -vf \"scale=trunc(in_w/2)*2+1:trunc(in_h/2)*2+1\" ",
    }
}
