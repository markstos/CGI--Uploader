# Please don't remove the next line. Thanks. -mark
#arch-tag: Mark_Stosberg_<mark@summersault.com>--2004-04-18_16:18:45

use Test::More qw/no_plan/;
use Test::Differences;
use Carp::Assert;
use lib 'lib';
use strict;

BEGIN { 
    use_ok('CGI::Uploader');
    use_ok('Digest::MD5');
    use_ok('File::Path');
    use_ok('DBI');
    use_ok('CGI');
};

    use vars qw($dsn $user $password);
    my $file ='t/cgi-uploader.config';
    my $return;
    unless ($return = do $file) {
        warn "couldn't parse $file: $@" if $@;
        warn "couldn't do $file: $!"    unless defined $return;
        warn "couldn't run $file"       unless $return;
    }
    ok($return, 'loading configuration');


    my $DBH =  DBI->connect($dsn,$user,$password);
    ok($DBH,'connecting to database'), 

	 my %imgs = (
		'img_1' => [],
	 );

	 my $u = 	CGI::Uploader->new(
		updir_path=>'t/uploads',
		updir_url=>'http://localhost/test',
		dbh  => $DBH,
		spec => \%imgs,
        query => CGI->new(),
        file_scheme => 'md5',
	 );
	 ok($u, 'Uploader object creation');

     my $loc;
     eval { $loc = $u->build_loc('123','.jpg'); };
     is($@,'', 'build_loc() survives');
     is($loc, '2/0/2/123.jpg', "file_scheme => 'md5' works"); 


# We use an end block to clean up even if the script dies.
END {
    rmtree(['t/uploads/2']); 
    $DBH->disconnect;
};
 

