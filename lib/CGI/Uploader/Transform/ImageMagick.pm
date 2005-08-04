package CGI::Uploader::Transform::ImageMagick;

use base 'Exporter';
use File::Temp qw/tempfile/;
use Params::Validate (qw/:all/);
use Carp::Assert;
use vars (qw/@EXPORT $VERSION/);

$VERSION = 1.1_1;

@EXPORT = (qw/&gen_thumb/);

=head2 gen_thumb()

 ($thumb_tmp_filename)  = CGI::Uploader->gen_thumb(
    $orig_filename, 
    [ w => $width, h => $height ]
    );

This function creates a copy of given image file and resizes the copy to the
provided width and height.

C<gen_thumb> can be called as object or class method. As a class method,
there there is no need to call C<new()> before calling this method.

L<Graphics::Magick> is used as the first choice image service module.
L<Image::Magick> is tried next. 

Input:

    filename - filename of source image 
    w        - max width of thumbnail
    h        - max height of thumbnail

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

    # Having both Graphics::Magick and Image::Magick loaded at the same time
    # can cause very strange problems, so we take care to avoid that
    # First see if we have already loaded Graphics::Magick or Image::Magick
    # If so, just use whichever one is already loaded.
    my $magick_module;
    if (exists $INC{'Graphics/Magick.pm'}) {
        $magick_module = 'Graphics::Magick';
    }
    elsif (exists $INC{'Image/Magick.pm'}) {
        $magick_module = 'Image::Magick';
    }

    # If neither are already loaded, try loading either one.
    elsif ( _load_magick_module('Graphics::Magick') ) {
        $magick_module = 'Graphics::Magick';
    }
    elsif ( _load_magick_module('Image::Magick') ) {
        $magick_module = 'Image::Magick';
    }

    my ($thumb_tmp_fh, $thumb_tmp_filename) = tempfile('CGIuploaderXXXXX', UNLINK => 1);
    binmode($thumb_tmp_fh);

    if ($magick_module) {
        my $img = $magick_module->new();
        my $err;
        eval {
          $err = $img->Read(filename=>$orig_filename);
          die "Error while reading $orig_filename: $err" if $err;

          my ($target_w,$target_h) = _calc_target_size($img,$p{w},$p{h});

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
    else {
        die "No graphics module found for image resizing. Install Graphics::Magick or Image::Magick: $@ "
    }

    assert ($thumb_tmp_filename, 'thumbnail tmp file created');
    return $thumb_tmp_filename;

}

# Calculate the target with height
# 
# my ($target_w,$target_h) = _calc_target_size($img,$p{w},$p{h})
# 
# Input:
# 
#   - Magick object, pre-opened with the original file
#   - provided width
#   - provided height

sub _calc_target_size {
    my ($img,$w,$h) = @_;

    my $target_h = $h;
    my $target_w = $w;
    my ($orig_w,$orig_h) = $img->Get('width','height');

    $target_h = sprintf("%.1d", ($orig_h * $target_w) / $orig_w) unless $target_h;
    $target_w = sprintf("%.1d", ($orig_w * $target_h) / $orig_h) unless $target_w;

    return ($target_w,$target_h);

}




# load Graphics::Magick or Image::Magick if one is not already loaded.
sub _load_magick_module {
    my $module_name = shift;
    eval {
        local $SIG{__DIE__};
        require $module_name;
    };
    return !$@;
}


1;
