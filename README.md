Pyazo2
======

Gyazo and Gifzo compatible server by perl

install and run
====

```
carton install 
cp config/development.pl.sample config/development.pl
vi config/development.pl # if you use Gifzo compatible.
carton exec plackup script/pyazo2-server

# or create config/production.pl
# carton exec plackup script/pyazo2-server -E production
```

how to use with Mac gyazo client
================================
please edit ```Gyazo.app/Contents/MacOS/Gyazo```

```
HOST = 'your_host_name'
CGI = '/'
UA   = 'Gyazo/1.0'
```
and

```
Net::HTTP.start(HOST,5000){|http|
```

(Huh? Windows? I dont know...)


Gifzo compatible is optional.
====

If you want use Gifzo compatible, You must install ffmpeg and gifsicle or (ImageMagick( or YoyaMagick)).


## require ffmpeg >= 1.2.x

using scaling option(vh).

> see also static build. http://johnvansickle.com/ffmpeg/


how to use with Mac Gifzo client
================================

[Gifzo Client - https://github.com/cockscomb/Gifzo.app](https://github.com/cockscomb/Gifzo.app)

set settings.

```
$ defaults write net.gifzo.Gifzo url -string "http://your_pyazo_2/"
```

check settings.

```
$  defaults read net.gifzo.Gifzo
{
    url = "http://your_pyazo_2/";
}
```

back to default.

```
$ defaults delete net.gifzo.Gifzo"
```

(Huh? Windows? I dont know...)



config options
====

(document not yet)


Sample
====

Pyazo2 is using in Yancha
http://yancha.hachiojipm.org/


see also
====

Gyazo
http://gyazo.com/ja

Gifzo
http://gifzo.net/
