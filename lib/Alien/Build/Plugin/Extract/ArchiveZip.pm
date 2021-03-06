package Alien::Build::Plugin::Extract::ArchiveZip;

use strict;
use warnings;
use Alien::Build::Plugin;

# ABSTRACT: Plugin to extract a tarball using Archive::Tar
# VERSION

=head1 SYNOPSIS

 use alienfile;
 plugin 'Extract::ArchiveZip' => (
   format => 'zip',
 );

=head1 DESCRIPTION

Note: in most case you will want to use L<Alien::Build::Plugin::Extract::Negotiate>
instead.  It picks the appropriate Extract plugin based on your platform and environment.
In some cases you may need to use this plugin directly instead.

This plugin extracts from an archive in zip format using L<Archive::Zip>.

=head2 format

Gives a hint as to the expected format.  This should always be C<zip>.

=cut

has '+format' => 'zip';

=head1 METHODS

=head2 handles

 Alien::Build::Plugin::Extract::ArchiveZip->handles($ext);
 $plugin->handles($ext);

Returns true if the plugin is able to handle the archive of the
given format.

=cut

sub handles
{
  my($class, $ext) = @_;
  
  return 1 if $ext eq 'zip';
  
  return;
}

sub init
{
  my($self, $meta) = @_;
  
  $meta->add_requires('share' => 'Archive::Zip' => 0);
  
  $meta->register_hook(
    extract => sub {
      my($build, $src) = @_;
      my $zip = Archive::Zip->new;
      $zip->read($src);
      $zip->extractTree;
    }
  );
}

1;

=head1 SEE ALSO

L<Alien::Build::Plugin::Extract::Negotiate>, L<Alien::Build>, L<alienfile>, L<Alien::Build::MM>, L<Alien>

=cut
