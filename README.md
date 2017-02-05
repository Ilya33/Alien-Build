# Alien::Build [![Build Status](https://secure.travis-ci.org/plicease/Alien-Build.png)](http://travis-ci.org/plicease/Alien-Build) [![Build status](https://ci.appveyor.com/api/projects/status/22odutjphx45248s/branch/master?svg=true)](https://ci.appveyor.com/project/plicease/Alien-Build/branch/master)

Build external dependencies for use in CPAN

# SYNOPSIS

    my $build = Alien::Build->load('./alienfile');
    $build->load_requires('configure');
    $build->set_prefix('/usr/local');
    $build->set_stage('/foo/mystage');  # needs to be absolute
    $build->load_requires($build->install_type);
    $build->download;
    $build->build;
    # files are now in /foo/mystage, it is your job (or
    # ExtUtils::MakeMaker, Module::Build, etc) to copy
    # those files into /usr/local

# DESCRIPTION

**NOTE**: This is still experimental, and documentation is currently highly
incomplete.

This module provides tools for building external (non-CPAN) dependencies 
for CPAN.  It is mainly designed to be used at install time of a CPAN 
client, and work closely with [Alien::Base](https://metacpan.org/pod/Alien::Base) which is used at runtime.

This is the detailed documentation for [Alien::Build](https://metacpan.org/pod/Alien::Build) class.  If you are
starting out as a user of an [Alien::Build](https://metacpan.org/pod/Alien::Build) based [Alien](https://metacpan.org/pod/Alien) module, see
[Alien::Build::Manual::AlienUser](https://metacpan.org/pod/Alien::Build::Manual::AlienUser).  If you are starting out writing a new
[Alien::Build](https://metacpan.org/pod/Alien::Build) based [Alien](https://metacpan.org/pod/Alien) module, see [Alien::Build::Manual::ALienAuthor](https://metacpan.org/pod/Alien::Build::Manual::ALienAuthor).
As an [Alien](https://metacpan.org/pod/Alien) author, you will also likely be interested in
[Alien::Build::Manual::FAQ](https://metacpan.org/pod/Alien::Build::Manual::FAQ).  If you are interested in writing a
[Alien::Build](https://metacpan.org/pod/Alien::Build) plugin, see [Alien::Build::Manual::PluginAuthor](https://metacpan.org/pod/Alien::Build::Manual::PluginAuthor).

Note that you will usually not usually create a [Alien::Build](https://metacpan.org/pod/Alien::Build) instance
directly, but rather be using a thin installer layer, such as
[Alien::Build::MM](https://metacpan.org/pod/Alien::Build::MM) (for use with [ExtUtils::MakeMaker](https://metacpan.org/pod/ExtUtils::MakeMaker)).  One of the
goals of this project is to remain installer agnostic.

# CONSTRUCTOR

## new

    my $build = Alien::Build->new;

This creates a new empty instance of [Alien::Build](https://metacpan.org/pod/Alien::Build).  Normally you will
want to use `load` below to create an instance of [Alien::Build](https://metacpan.org/pod/Alien::Build) from
an [alienfile](https://metacpan.org/pod/alienfile) recipe.

# PROPERTIES

There are three main properties for [Alien::Build](https://metacpan.org/pod/Alien::Build).  There are a number
of properties documented here with a specific usage.  Note that these
properties may need to be serialized into something primitive like JSON
that does not support: regular expressions, code references of blessed
objects.

If you are writing a plugin ([Alien::Build::Plugin](https://metacpan.org/pod/Alien::Build::Plugin)) you should use a 
prefix like "plugin\__name_" (where _name_ is the name of your plugin) 
so that it does not interfere with other plugin or future versions of
[Alien::Build](https://metacpan.org/pod/Alien::Build).  For example, if you were writing
`Alien::Build::Plugin::Fetch::NewProtocol`, please use the prefix
`plugin_fetch_newprotocol`:

    sub init
    {
      my($self, $meta) = @_;
      
      $meta->prop( plugin_fetch_newprotocol_foo => 'some value' );
      
      $meta->register_hook(
        some_hook => sub {
          my($build) = @_;
          $build->install_prop->{plugin_fetch_newprotocol_bar => 'some other value' );
          $build->runtime_prop->{plugin_fetch_newprotocol_baz => 'and another value' );
        }
      );
    }

If you are writing a [alienfile](https://metacpan.org/pod/alienfile) recipe please use the prefix `my_`:

    # alienfile
    meta_prop->{my_foo} = 'some value';
    
    probe sub {
      my($build) = @_;
      $build->install_prop->{my_bar} = 'some other value';
      $build->install_prop->{my_baz} = 'and another value';
    };

Any property may be used from a command:

    probe [ 'some command %{alien.meta.plugin_fetch_newprotocol_foo}' ];
    probe [ 'some command %{alien.install.plugin_fetch_newprotocol_bar}' ];
    probe [ 'some command %{alien.runtime.plugin_fetch_newprotocol_baz}' ];
    probe [ 'some command %{alien.meta.my_foo}' ];
    probe [ 'some command %{alien.install.my_bar}' ];
    probe [ 'some command %{alien.runtime.my_baz}' ];

## meta\_prop

    my $href = $build->meta_prop;
    my $href = Alien::Build->meta_prop;

Meta properties have to do with the recipe itself, and not any particular
instance that probes or builds that recipe.  Meta properties can be changed
from within an [alienfile](https://metacpan.org/pod/alienfile) using the `meta_prop` directive, or from
a plugin from its `init` method (though should NOT be modified from any
hooks registered within that `init` method).  This is not strictly enforced,
but if you do not follow this rule your recipe will likely be broken.

- arch

    This is a hint to an installer like [Alien::Build::MM](https://metacpan.org/pod/Alien::Build::MM) or [Alien::Build::MB](https://metacpan.org/pod/Alien::Build::MB),
    that the library or tool contains architecture dependent files and so should
    be stored in an architecture dependent location.  If not specified by your
    [alienfile](https://metacpan.org/pod/alienfile) then it will be set to true.

- destdir

    Use the `DESTDIR` environment variable to stage your install before
    copying the files into `blib`.  This is the preferred method of
    installing libraries because it improves reliability.  This technique
    is supported by `autoconf` and others.

- destdir\_filter

    Regular expression for the files that should be copied from the `DESTDIR`
    into the stage directory.  If not defined, then all files will be copied.

- platform

    Hash reference.  Contains information about the platform beyond just `$^O`.

    - compiler\_type

        Refers to the type of flags that the compiler accepts.  May be expanded in the
        future, but for now, will be one of:

        - microsoft

            On Windows when using Microsoft Visual C++

        - unix

            Virtually everything else, including gcc on windows.

        The main difference is that with Visual C++ `-LIBPATH` should be used instead
        of `-L`, and static libraries should have the `.LIB` suffix instead of `.a`.

## install\_prop

    my $href = $build->install_prop;

Install properties are used during the install phase (either
under `share` or `system` install).  They are remembered for
the entire install phase, but not kept around during the runtime
phase.  Thus they cannot be accessed from your [Alien::Base](https://metacpan.org/pod/Alien::Base)
based module.

- root

    The build root directory.  This will be an absolute path.  It is the
    absolute form of `./_alien` by default.

- patch

    Directory with patches.

- prefix

    The install time prefix.  Under a `destdir` install this is the
    same as the runtime or final install location.  Under a non-`destdir`
    install this is the `stage` directory (usually the appropriate
    share directory under `blib`).

- autoconf\_prefix

    The prefix as understood by autoconf.  This is only different on Windows
    Where MSYS is used and paths like `C:/foo` are  represented as `/C/foo`
    which are understood by the MSYS tools, but not by Perl.  You should
    only use this if you are using [Alien::Build::Plugin::Autoconf](https://metacpan.org/pod/Alien::Build::Plugin::Autoconf) in
    your [alienfile](https://metacpan.org/pod/alienfile).

- stage

    The stage directory where files will be copied.  This is usually the
    root of the blib share directory.

## runtime\_prop

    my $href = $build->runtime_prop;

Runtime properties are used during the install and runtime phases
(either under `share` or `system` install).  This should include
anything that you will need to know to use the library or tool
during runtime, and shouldn't include anything that is no longer
relevant once the install process is complete.

- cflags

    The compiler flags

- cflags\_static

    The static compiler flags

- command

    The command name for tools where the name my differ from platform to
    platform.  For example, the GNU version of make is usually `make` in
    Linux and `gmake` on FreeBSD.

- libs

    The library flags

- libs\_static

    The static library flags

- version

    The version of the library or tool

- prefix

    The final install root.  This is usually they share directory.

- install\_type

    The install type.  Is one of:

    - system

        For when the library or tool is provided by the operating system, can be
        detected by [Alien::Build](https://metacpan.org/pod/Alien::Build), and is considered satisfactory by the
        `alienfile` recipe.

    - share

        For when a system install is not possible, the library source will be
        downloaded from the internet or retrieved in another appropriate fashion
        and built.

# METHODS

## load

    my $build = Alien::Build->load($alienfile);

This creates an [Alien::Build](https://metacpan.org/pod/Alien::Build) instance with the given [alienfile](https://metacpan.org/pod/alienfile)
recipe.

## checkpoint

    $build->checkpoint;

Save any install or runtime properties so that they can be reloaded on
a subsequent run.  This is useful if your build needs to be done in
multiple stages from a `Makefile`, such as with [ExtUtils::MakeMaker](https://metacpan.org/pod/ExtUtils::MakeMaker).

## resume

    my $build = Alien::Build->resume($alienfile, $root);

Load a checkpointed [Alien::Build](https://metacpan.org/pod/Alien::Build) instance.  You will need the original
[alienfile](https://metacpan.org/pod/alienfile) and the build root (usually `_alien`).

## root

    my $dir = $build->root;

This is just a shortcut for:

    my $root = $build->install_prop->{root};

Except that it will be created if it does not already exist.  

## install\_type

    my $type = $build->install_type;

This will return the install type.  (See the like named install property
above for details).  This method will call `probe` if it has not already
been called.

## set\_prefix

    $build->set_prefix($prefix);

Set the final (unstaged) prefix.  This is normally only called by [Alien::Build::MM](https://metacpan.org/pod/Alien::Build::MM)
and similar modules.  It is not intended for use from plugins or from an [alienfile](https://metacpan.org/pod/alienfile).

## set\_stage

    $build->set_stage($dir);

Sets the stage directory.  This is normally only called by [Alien::Build::MM](https://metacpan.org/pod/Alien::Build::MM)
and similar modules.  It is not intended for use from plugins or from an [alienfile](https://metacpan.org/pod/alienfile).

## requires

    my $hash = $build->requires($phase);

Returns a hash reference of the modules required for the given phase.  Phases
include:

- configure

    These modules must already be available when the [alienfile](https://metacpan.org/pod/alienfile) is read.

- any

    These modules are used during either a `system` or `share` install.

- share

    These modules are used during the build phase of a `share` install.

- system

    These modules are used during the build phase of a `system` install.

## load\_requires

    $build->load_requires($phase);

This loads the appropriate modules for the given phase (see `requires` above
for a description of the phases).

## probe

    my $install_type = $build->probe;

Attempts to determine if the operating system has the library or
tool already installed.  If so, then the string `system` will
be returned and a system install will be performed.  If not,
then the string `share` will be installed and the tool or
library will be downloaded and built from source.

If the environment variable `ALIEN_INSTALL_TYPE` is set, then that
will force a specific type of install.  If the detection logic
cannot accommodate the install type requested then it will fail with
an exception.

## download

    $build->download;

Download the source, usually as a tarball, usually from the internet.

Under a `system` install this does not do anything.

## fetch

    my $res = $build->fetch;
    my $res = $build->fetch($url);

Fetch a resource using the fetch hook.  Returns the same hash structure
described below in the hook documentation.

## decode

    my $decoded_res = $build->decode($res);

Decode the HTML or file listing returned by `fetch`.  Returns the same
hash structure described below in the hook documentation.

## prefer

    my $sorted_res = $build->prefer($res);

Filter and sort candidates.  The preferred candidate will be returned first in the list.
The worst candidate will be returned last.  Returns the same hash structure described
below in the hook documentation.

## extract

    my $dir = $build->extract;
    my $dir = $build->extract($archive);

Extracts the given archive into a fresh directory.  This is normally called internally
to [Alien::Build](https://metacpan.org/pod/Alien::Build), and for normal usage is not needed from a plugin or [alienfile](https://metacpan.org/pod/alienfile).

## build

    $build->build;

Run the build step.  It is expected that `probe` and `download`
have already been performed.  What it actually does depends on the
type of install:

- share

    The source is extracted, and built as determined by the [alienfile](https://metacpan.org/pod/alienfile)
    recipe.  If there is a `gather_share` that will be executed last.

- system

    The `gather_system` hook will be executed.

## meta

    my $meta = Alien::Build->meta;
    my $meta = $build->meta;

Returns the meta object for your [Alien::Build](https://metacpan.org/pod/Alien::Build) class or instance.  The
meta object is a way to manipulate the recipe, and so any changes to the
meta object should be made before the `probe`, `download` or `build` steps.

# META METHODS

## prop

    my $href = $build->meta->prop;
    my $href = Alien::Build->meta->prop;

Meta properties.  This is the same as calling `meta_prop` on
the class or [Alien::Build](https://metacpan.org/pod/Alien::Build) instance.

## add\_requires

    Alien::Build->meta->add_requires($phase, $module => $version, ...);

Add the requirement to the given phase.  Phase should be one of:

- configure
- any
- share
- system

## interpolator

    my $interpolator = $build->meta->interpolator;
    my $interpolator = Alien::Build->interpolator;

Returns the [Alien::Build::Interpolate](https://metacpan.org/pod/Alien::Build::Interpolate) instance for the [Alien::Build](https://metacpan.org/pod/Alien::Build) class.

## has\_hook

    my $bool = $build->meta->has_hook($name);
    my $bool = Alien::Build->has_hook($name);

Returns if there is a usable hook registered with the given name.

## register\_hook

    $build->meta->register_hook($name, $instructions);
    Alien::Build->meta->register_hook($name, $instructions);

Register a hook with the given name.  `$instruction` should be either
a code reference, or a command sequence, which is an array reference.

## default\_hook

    $build->meta->default_hook($name, $instructions);
    Alien::Build->meta->default_hook($name, $instructions);

Register a default hook, which will be used if the [alienfile](https://metacpan.org/pod/alienfile) does not
register its own hook with that name.

## around\_hook

    $build->meta->around_hook($hook, $code);
    Alien::Build->meta->around_hook($name, $code);

Wrap the given hook with a code reference.  This is similar to a [Moose](https://metacpan.org/pod/Moose)
method modifier, except that it wraps around the given hook instead of
a method.  For example, this will add a probe system requirement:

    $build->meta->around_hook(
      probe => sub {
        my $orig = shift;
        my $build = shift;
        my $type = $orig->($build, @_);
        return $type unless $type eq 'system';
        # also require a configuration file
        if(-f '/etc/foo.conf')
        {
          return 'system';
        }
        else
        {
          return 'share';
        }
      },
    );

# ENVIRONMENT

[Alien::Build](https://metacpan.org/pod/Alien::Build) responds to these environment variables:

- ALIEN\_INSTALL\_TYPE

    If set to `share` or `system`, it will override the system detection logic.

- ALIEN\_BUILD\_PRELOAD

    semicolon separated list of plugins to automatically load before parsing
    your [alienfile](https://metacpan.org/pod/alienfile).

- ALIEN\_BUILD\_PRELOAD

    semicolon separated list of plugins to automatically load after parsing
    your [alienfile](https://metacpan.org/pod/alienfile).

- DESTDIR

    This environment variable will be manipulated during a destdir install.

- PKG\_CONFIG

    This environment variable can be used to override the program name for `pkg-config`
    for some PkgConfig plugins: [Alien::Build::Plugin::PkgConfig](https://metacpan.org/pod/Alien::Build::Plugin::PkgConfig).

- ftp\_proxy, all\_proxy

    If these environment variables are set, it may influence the Download negotiation
    plugin [Alien::Build::Plugin::Downaload::Negotiate](https://metacpan.org/pod/Alien::Build::Plugin::Downaload::Negotiate).  Other proxy variables may
    be used by some Fetch plugins, if they support it.

# SEE ALSO

[Alien::Build::Manual::AlienAuthor](https://metacpan.org/pod/Alien::Build::Manual::AlienAuthor),
[Alien::Build::Manual::AlienUser](https://metacpan.org/pod/Alien::Build::Manual::AlienUser),
[Alien::Build::Manual::Contributing](https://metacpan.org/pod/Alien::Build::Manual::Contributing),
[Alien::Build::Manual::FAQ](https://metacpan.org/pod/Alien::Build::Manual::FAQ),
[Alien::Build::Manual::PluginAuthor](https://metacpan.org/pod/Alien::Build::Manual::PluginAuthor)

[alienfile](https://metacpan.org/pod/alienfile), [Alien::Build::MM](https://metacpan.org/pod/Alien::Build::MM), [Alien::Build::Plugin](https://metacpan.org/pod/Alien::Build::Plugin), [Alien::Base](https://metacpan.org/pod/Alien::Base), [Alien](https://metacpan.org/pod/Alien)

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
