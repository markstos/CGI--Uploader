package CGI::Uploader::Transform::ImageMagick;

use base 'Exporter';
use Image::Size;
use File::Temp qw/tempfile/;
use Params::Validate (qw/:all/);
use Carp::Assert;
use vars (qw/@EXPORT $VERSION/);

$VERSION = 1.1_1;

@EXPORT = (qw/&gen_thumb/);

=head2 gen_thumb()

 ($thumb_tmp_filename)  = CGI::Uploader->gen_thumb(
    filename => $orig_filename,
    w => $width,
    h => $height,
    );

This function creates a copy of given image file and resizes the copy to the
provided width and height.

C<gen_thumb> can be called as object or class method. As a class method,
there there is no need to call C<new()> before calling this method.

Input:
    filename => filename of source image 
    w => max width of thumbnail
    h => max height of thumbnail

One or both  of C<w> or C<h> is required.

Output:
    - filename of generated tmp file for the thumbnail 

=cut

sub gen_thumb {
    my ($self, $orig_filename, $params) = validate_pos(@_,1,1,{
            type => ARRAYREF
        });
    my %p = validate(@$params,{ 
            w => { type => SCALAR | UNDEF, regex => qr/^\d*$/, optional => 1, },
            h => { type => SCALAR | UNDEF, regex => qr/^\d*$/, optional => 1 },
        });
    die "must supply 'w' or 'h'" unless (defined $p{w} or defined $p{h});

    my ($orig_w,$orig_h,$orig_fmt) = imgsize($orig_filename);

    my $target_h = $p{h};
    my $target_w = $p{w};

    $target_h = sprintf("%.1d", ($orig_h * $target_w) / $orig_w) unless $target_h;
    $target_w = sprintf("%.1d", ($orig_w * $target_h) / $orig_h) unless $target_w;

    my ($thumb_tmp_fh, $thumb_tmp_filename) = tempfile('CGIuploaderXXXXX', UNLINK => 1);
    binmode($thumb_tmp_fh);

    eval { require Image::Magick; };
    my $have_image_magick = !$@;
    eval { require GD; };
    my $have_gd = !$@; 

     my %gd_map = (
         'PNG' =>  'png',
         'JPG'  => 'jpeg',
         'GIF'  => 'gif',
     );

    if ($have_image_magick) {
        my $img = Image::Magick->new();
        my $err;
        eval {
          $err = $img->Read(filename=>$orig_filename);
          die "Error while reading $orig_filename: $err" if $err;
          $err = $img->Resize($target_w.'x'.$target_h); 
          die "Error while resizing $orig_filename: $err" if $err;
          $err = $img->Write($thumb_tmp_filename);
          die "Error while writing $orig_filename: $err" if $err;
        };
        if ($@) {
            warn $@;
            my $code;
            # codes > 400 are fatal 
            die $err if ((($code) = $err =~ /(\d+)/) and ($code > 400));
        }
    }
    elsif ($have_gd and (grep {m/^$orig_fmt$/} keys %gd_map)) {
		die "Image::Magick wasn't found and GD support is not complete. 
			Install Image::Magick or fix GD support. ";

        # This formula was figured out by Ehren Nagel
        my ($actual_w,$actual_h) = ($target_w,$target_h);
        my $potential_w  = ($target_h/$orig_h)*$orig_w;
        my $potential_h  = ($target_w/$orig_w)*$orig_h;

        if  (($orig_h > $orig_w ) and ($potential_w < $target_w)) {
            $actual_w = $potential_w;
        }
        elsif (($orig_h > $orig_w ) and ($potential_w >= $target_w)) {
            $actual_h = $potential_h;
        }
        elsif (($orig_h <=  $orig_w ) and ($potential_h < $target_h ))   {
            $actual_h = $potential_h;
        }
        elsif (($orig_h <=  $orig_w ) and ($potential_h >= $target_h ))   {
            $actual_w = $potential_w;
        }

        my $orig  = GD::Image->new("$orig_filename") || die "$!";
        my $thumb = GD::Image->new( $actual_w,$actual_h );
        $thumb->copyResized($orig,0,0,0,0,$actual_w,$actual_h,$orig_w,$orig_h);
        my $meth = $gd_map{$orig_fmt};
        no strict 'refs';
        no strict 'subs';
        binmode($thumb_tmp_fh); 
        print $thumb_tmp_fh, $thumb->$meth;
    }
    else {
        die "No graphics module found for image resizing. Install Image::Magick or GD.
        ( GD is only good for  PNG and JPEG, but may be easier to get installed ): $@ "
    }

    assert ($thumb_tmp_filename, 'thumbnail tmp file created');
    return $thumb_tmp_filename;

}

1;
