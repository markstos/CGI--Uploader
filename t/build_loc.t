use Test::More qw/no_plan/;
use Carp::Assert;
use lib 't/lib';
use CGI::Uploader::Test;
use strict;

BEGIN { 
    use_ok('CGI::Uploader');
    use_ok('Digest::MD5');
    use_ok('File::Path');
    use_ok('DBI');
    use_ok('CGI');
};

    my ($DBH,$drv) =  setup();

	 my %imgs = (
		'img_1' => [],
	 );

     use CGI;
     my $q = CGI->new;

	 my $u = 	CGI::Uploader->new(
		updir_path=>'t/uploads',
		updir_url=>'http://localhost/test',
		dbh  => $DBH,
		spec => \%imgs,
        query => $q,
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
};
 

