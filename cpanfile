requires 'Amon2', '5.11';
requires 'DBD::SQLite', '1.33';
requires 'HTML::FillInForm::Lite', '1.11';
requires 'JSON', '2.50';
requires 'Module::Functions', '2';
requires 'Plack::Middleware::ReverseProxy', '0.09';
requires 'Plack::Middleware::Session';
requires 'Plack::Session', '0.14';
requires 'Router::Boom', '0.06';
requires 'Starlet', '0.20';
requires 'Teng', '0.18';
requires 'Test::WWW::Mechanize::PSGI';
requires 'Text::Xslate', '2.0009';
requires 'Time::Piece', '1.20';
requires 'perl', '5.010_001';
requires 'File::Slurp';
requires 'Time::HiRes';
requires 'String::Random';
requires 'File::Basename';
requires 'Image::Info';
requires 'File::Path';
requires 'Media::Type::Simple';
requires 'LWP::UserAgent';
requires 'Path::Tiny';
requires 'File::Temp';
requires 'Imager';
requires 'Imager::ExifOrientation';
requires 'Imager::File::JPEG';
requires 'Imager::File::GIF';
requires 'Imager::File::PNG';


on configure => sub {
    requires 'Module::Build', '0.38';
    requires 'Module::CPANfile', '0.9010';
};

on test => sub {
    requires 'Test::More', '0.98';
};
