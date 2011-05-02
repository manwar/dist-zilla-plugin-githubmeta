package Dist::Zilla::Plugin::GithubMeta;

# ABSTRACT: Automatically include GitHub meta information in META.yml

use strict;
use warnings;
use Moose;
with 'Dist::Zilla::Role::MetaProvider';

use MooseX::Types::URI qw[Uri];
use Cwd;
use IPC::Cmd qw[can_run];

use namespace::autoclean;

has 'homepage' => (
  is => 'ro',
  isa => Uri,
  coerce => 1,
);

has 'remote' => (
  is  => 'ro',
  isa => 'ArrayRef[Str]',
  default => sub {  [ 'origin' ]  },
);

has 'issues' => (
  is  => 'ro',
  isa => 'Bool',
  default => 0,
);

has user => (
  is  => 'rw',
  isa => 'Str',
  predicate => '_has_user',
);

has repo => (
  is  => 'rw',
  isa => 'Str',
  predicate => '_has_repo',
);

sub _acquire_repo_info {
  my ($self) = @_;

  return if $self->_has_user and $self->_has_repo;

  return unless _under_git();
  return unless can_run('git');

  my $git_url;
  for my $remote (@{ $self->remote }) {
    next unless $git_url = $self->_url_for_remote($remote);
    last if $git_url =~ /github\.com/; # Not a Github repository
    undef $git_url;
  }

  return unless $git_url;

  my ($user, $repo) = $git_url =~ m{
    github\.com           # the domain
    / ([^/]+)             # the username
    / ([^/]+?) (?:\.git)? # the repo name
  }ix;

  return unless defined $user and defined $repo;

  $self->_user($user);
  $self->_repo($repo);
}

sub metadata {
  my $self = shift;

  $self->_acquire_repo_info;

  return unless $self->_has_user and $self->_has_repo;

  my $gh_url  = sprintf 'http://github.com/%s/%s', $self->user, $self->repo;
  my $bug_url = "$gh_url/issues";

  my $home_url = $self->homepage ? $self->homepage->as_string : $gh_url;

  return {
    resources => {
      homepage   => $home_url,
      repository => {
        type => 'git',
        url  => $gh_url,
        web  => $gh_url,
      },
      ($self->issues ? { bugtracker => { web => $bug_url } } : ()),
    }
  };
}

sub _url_for_remote {
  my ($self, $remote) = @_;
  my ($url) = `git remote show -n $remote` =~ /URL: (.*)$/m;

  return $url;
}

sub _under_git {
  return 1 if -e '.git';
  my $cwd = getcwd;
  my $last = $cwd;
  my $found = 0;
  while (1) {
    chdir '..' or last;
    my $current = getcwd;
    last if $last eq $current;
    $last = $current;
    if ( -e '.git' ) {
       $found = 1;
       last;
    }
  }
  chdir $cwd;
  return $found;
}

__PACKAGE__->meta->make_immutable;
no Moose;

qq[1 is the loneliest number];

=pod

=head1 SYNOPSIS

  # in dist.ini

  [GithubMeta]

  # to override the homepage

  [GithubMeta]
  homepage = http://some.sort.of.url/project/

  # to override the github remote repo (defaults to 'origin')
  [GithubMeta]
  remote=github

=head1 DESCRIPTION

Dist::Zilla::Plugin::GithubMeta is a L<Dist::Zilla> plugin to include GitHub L<http://github.com> meta
information in C<META.yml>.

It automatically detects if the distribution directory is under C<git> version control and whether the 
C<origin> is a GitHub repository and will set the C<repository> and C<homepage> meta in C<META.yml> to the
appropriate URLs for GitHub. 

Based on L<Module::Install::GithubMeta> which was based on 
L<Module::Install::Repository> by Tatsuhiko Miyagawa

=head2 ATTRIBUTES

=over

=item C<remote>

The GitHub remote repo can be overriden with this attribute. If not
provided, it defaults to C<origin>.

=item C<homepage>

You may override the C<homepage> setting by specifying this attribute. This should be a valid URL as 
understood by L<MooseX::Types::URI>.

=back

=head2 METHODS

=over

=item C<metadata>

Required by L<Dist::Zilla::Role::MetaProvider>

=back

=head1 SEE ALSO

L<Dist::Zilla>

=cut
