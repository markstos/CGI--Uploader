use Test::More;
use Carp::Assert;
use strict;

BEGIN { 
    use_ok('CGI::Uploader');
    use_ok('File::Path');
};

my $found_module = 0;
eval { require Image::Magick; };
$found_module = !$@;
if ($found_module) {
    plan (qw/no_plan/)
}
else {
    eval { require Graphics::Magick; };
    $found_module = !$@;
    if ($found_module) {
        plan (qw/no_plan/)
    }
    else {
        plan skip_all => "No graphics module found for image resizing. Install Graphics::Magick or Image::Magick: $@ ";
    }
}

use CGI::Uploader::Transform::ImageMagick;

 my ($tmp_filename, $img)  = CGI::Uploader::Transform::ImageMagick->gen_thumb( 't/20x16.png', [ w => 5 ]);

 my ($w,$h) = $img->Get('width','height');

 is($w,5,'as class method - correct height only width is supplied');
 is($h,4,'as class method - correct height only width is supplied');


####

    use vars qw($dsn $user $password);
    my $file ='t/cgi-uploader.config';
    my $return;
    unless ($return = do $file) {
        warn "couldn't parse $file: $@" if $@;
        warn "couldn't do $file: $!"    unless defined $return;
        warn "couldn't run $file"       unless $return;
    }
    ok($return, 'loading configuration');

    use DBI;
    my $DBH =  DBI->connect($dsn,$user,$password);
    ok($DBH,'connecting to database'), 

	 my %imgs = (
		'img_1' => {
            gen_files => {
                img_1_thumb => {
                    transform_method => \&gen_thumb,
                    params => [{ w => 10 }],
                },
            },
        },
	 );

     use CGI;
	 my $u = 	CGI::Uploader->new(
		updir_path=>'t/uploads',
		updir_url=>'http://localhost/test',
		dbh  => $DBH,
		spec => \%imgs,
        query => CGI->new(),
	 );
	 ok($u, 'Uploader object creation');

{
     my ($tmp_filename,$img)  = CGI::Uploader::Transform::ImageMagick->gen_thumb( 't/20x16.png', [ w => 10 ]);
     my ($w,$h) = $img->Get('width','height');
     is($h,8,'correct height only width is supplied');
}

{
     my ($tmp_filename,$img)  = CGI::Uploader::Transform::ImageMagick->gen_thumb( 't/20x16.png', [ h => 8 ]);
     my ($w,$h) = $img->Get('width','height');
     is($w,10,'correct width only width is supplied');
}

###
# create uploads table
my $drv = $DBH->{Driver}->{Name};

ok(open(IN, "<create_uploader_table.".$drv.".sql"), 'opening SQL create file');
my $sql = join "\n", (<IN>);
my $created_up_table = $DBH->do($sql);
ok($created_up_table, 'creating uploads table');

ok(open(IN, "<t/create_test_table.sql"), 'opening SQL create test table file');
$sql = join "\n", (<IN>);

# Fix mysql non-standard quoting
$sql =~ s/"/`/gs if ($drv eq 'mysql');

my $created_test_table = $DBH->do($sql);
ok($created_test_table, 'creating test table');

SKIP: {
	 skip "Couldn't create database table", 20 unless $created_up_table;

     eval {
         my %entity_upload_extra = $u->store_upload(
             file_field  => 'img_1',
             src_file    => 't/20x16.png',
             uploaded_mt => 'image/png',
             file_name   => '20x16.png',
             );
         };
    is($@,'', 'store_upload() survives');

    my $db_height =$DBH->selectrow_array(
        "SELECT height
            FROM uploads 
            WHERE upload_id = 2");
    is($db_height, 8, "correct height calculation when thumb height omitted from spec ");

}

	
# We use an end block to clean up even if the script dies.
END {
 	unlink <t/uploads/*>;
 	if ($DBH) {
 		if ($created_up_table) {
 			$DBH->do("DROP SEQUENCE upload_id_seq") if ($drv eq 'Pg');
 			$DBH->do("DROP TABLE uploads");
 		}
 		if ($created_test_table) {
 			$DBH->do('DROP TABLE cgi_uploader_test');
 		}
 		$DBH->disconnect;
 	}
    $DBH->disconnect;
};
 

