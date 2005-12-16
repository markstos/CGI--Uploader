# Please don't remove the next line. Thanks. -mark
#arch-tag: Mark_Stosberg_<mark@summersault.com>--2004-04-18_15:50:47

use Test::More qw/no_plan/;
use Carp::Assert;
use lib 'lib';
use strict;

BEGIN { use_ok('CGI::Uploader') };
BEGIN { use_ok('DBI') };
BEGIN { 
    use_ok('CGI');
    use_ok('Image::Magick');
    use_ok('CGI::Uploader::Transform::ImageMagick');
};

my $q = new CGI;

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

     $DBH->do("ALTER TABLE uploads ADD COLUMN custom char(64)");

	 my %imgs = (
		'img_1' => {
            gen_files => {
                img_1_thumb => {
                    transform_method => \&gen_thumb,
                    params => [{ w => 50, h => 60 }],
                },
            },
        },
	 );

	 my $u = 	CGI::Uploader->new(
		updir_path=>'t/uploads',
		updir_url=>'http://localhost/test',
		dbh => $DBH,
		query => $q,
		spec => \%imgs,
        up_table_map => {
            upload_id => 'upload_id',
            mime_type => 'mime_type',
            extension => 'extension',
            width     => 'width',
            height    => 'height',
            custom    => undef,
        }
	 );
	 ok($u, 'Uploader object creation');

     eval {
         my %entity_upload_extra = $u->store_upload(
             file_field  => 'img_1',
             src_file    => 't/200x200.gif',
             uploaded_mt => 'image/gif',
             file_name   => '200x200.gif',
             shared_meta => { custom => 'custom_value' },
             );
         };
    is($@,'', 'store_upload() survives');

    my $imgs_with_custom_value =$DBH->selectrow_array(
        "SELECT count(*) 
            FROM uploads 
            WHERE custom = 'custom_value'");
    is($imgs_with_custom_value,2, 'both img and thumbnail have shared_meta');

    # testing transform_meta
    my $img_href = $DBH->selectrow_hashref("SELECT * FROM uploads WHERE upload_id = 1");

    my %meta =  $u->transform_meta( 
        meta   => $img_href,
        prefix => 'test',
        prevent_browser_caching => 1,
        fields => [qw/id url width height/],
    );

    is($meta{test_id}, 1,      'meta_hashref id');
    is($meta{test_width}, 200, 'meta_hashref width');
    is($meta{test_height}, 200, 'meta_hashref height');
    ok((not exists $meta{test_extension}), 'meta_hashref extension');
    like($meta{test_url}, qr!http://localhost/test/1.gif\?!, 'meta_hashref url');

    # Now test a mapped field







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
};
 

