use Test2::V0 -no_srand => 1;
use Test::Alien::Build;
use lib 't/lib';
use lib 'corpus/lib';
use MyTest::System;
use Alien::Build;
use Capture::Tiny qw( capture_merged );
use File::chdir;
use Path::Tiny qw( path );
use Alien::Build::Util qw( _dump );

subtest 'simple new' => sub {
  my $build = MyBuild->new;
  
  isa_ok $build, 'Alien::Build';

  isa_ok( $build->meta, 'Alien::Build::Meta' );
  isa_ok( MyBuild->meta, 'Alien::Build::Meta' );
  note(_dump $build->meta);

};

subtest 'from file' => sub {

  my $build = Alien::Build->load('corpus/basic/alienfile');
  
  isa_ok $build, 'Alien::Build';

  isa_ok( $build->meta, 'Alien::Build::Meta' );

  note(_dump $build->meta);

  is( $build->requires,              { Foo => '1.00' },                'any'       );
  is( $build->requires('share'),     { Foo => '1.00', Bar => '2.00' }, 'share'     );
  is( $build->requires('system'),    { Foo => '1.00', Baz => '3.00' }, 'system'    );
  is( $build->requires('configure'), { 'Early::Module' => '1.234' },   'configure' );

  my $intr = $build->meta->interpolator;
  isa_ok $intr, 'Alien::Build::Interpolate::Default';

};

subtest 'invalid alienfile' => sub {

  eval { Alien::Build->load('corpus/basic/alienfilex') };
  like $@, qr{Unable to read alienfile: };

};

subtest 'load requires' => sub {

  my $build = alienfile filename => 'corpus/blank/alienfile';
  my $meta = $build->meta;
  
  note(_dump $meta);
  
  is( $build->load_requires, 1, 'empty loads okay' );

  $meta->add_requires( 'any' => 'Foo::Bar::Baz' => '1.00');
  is( $build->load_requires, 1, 'have it okay' );
  ok $INC{'Foo/Bar/Baz.pm'};
  note "inc=$INC{'Foo/Bar/Baz.pm'}";

  $meta->add_requires( 'any' => 'Foo::Bar::Baz1' => '2.00');
  eval { $build->load_requires };
  my $error = $@;
  isnt $error, '';
  note "error=$error";
};

subtest 'hook' => sub {

  my $build = alienfile filename => 'corpus/blank/alienfile';
  my $meta = $build->meta;
  
  subtest 'simple single working hook' => sub {
  
    my @foo1;
    my $props;
  
    $meta->register_hook(
      foo1 => sub {
        @foo1 = @_;
        my($build) = @_;
        $props = $build->hook_prop;
        return 42;
      }
    );
  
    is( $build->hook_prop, undef );  
  
    is( $build->_call_hook(foo1 => ('roger', 'ramjet')), 42);

    is(
      $props,
      hash {
        field name => 'foo1';
        etc;
      },
    );

    is( $build->hook_prop, undef );  

    is(
      \@foo1,
      array {
        item object {
          prop blessed => ref $build;
          call sub { shift->isa('Alien::Build') } => T();
        };
        item 'roger';
        item 'ramjet';
      }
    );
  };

  my $exception_count = 0;
  
  $meta->register_hook(
    foo2 => sub {
      $exception_count++;
      die "throw exception";
    }
  );
  
  subtest 'single failing hook' => sub {
    
    $exception_count = 0;
    
    eval { $build->_call_hook(foo2 => ()) };
    like $@, qr/throw exception/;
    note "error = $@";
    is $exception_count, 1;
  
  };
  
  subtest 'one fail, one okay' => sub {
  
    $exception_count = 0;
    
    $meta->register_hook(
      foo2 => sub {
        99;
      }
    );
    
    is( $build->_call_hook(foo2 => ()), 99);
    is $exception_count, 1;
  
  };
  
  subtest 'invalid hook' => sub {
  
    eval { $build->_call_hook(foo3 => ()) };
    like $@, qr/No hooks registered for foo3/;
  
  };
  
  subtest 'command list hook' => sub {
  
    $meta->register_hook(
      foo4 => [[$^X, -e => 'print @ARGV', 'hello', ' ', 'world']],
    );
    
    my $out = capture_merged { $build->_call_hook('foo4') };
    note $out;
    
    like $out, qr/hello world/s;
  
  };
  
  subtest 'command with failure' => sub {
  
    $meta->register_hook(
      foo5 => [[$^X, -e => 'exit 1']],
    );
    
    my $error;
    note capture_merged {
      eval { $build->_call_hook('foo5') };
      $error = $@;
    };
    
    like $error, qr/external command failed/;
  
  };
  
  subtest 'command with failure, followed by good command' => sub {
  
    $meta->register_hook(
      foo5 => [[$^X, -e => '']],
    );
    
    note capture_merged {
      $build->_call_hook('foo5');
    };
    
    ok 1;
  
  };
  
  subtest 'around hook' => sub {
  
    subtest 'single wrapper' => sub {
    
      my @args;
    
      $meta->register_hook(
        foo6 => sub {
          my $build = shift;
          @args = @_;
          die "oops" unless $build->isa('Alien::Build');
          return 'platypus';
        },
      );
      
      $meta->around_hook(
        foo6 => sub {
          my $orig = shift;
          return $orig->(@_) . ' man';
        }
      );
      
      is( $build->_call_hook('foo6', 1, 2), 'platypus man', 'return value' );
      is( \@args, [1,2], 'arguments' );
    
    };
    
    subtest 'double wrapper' => sub {
    
      my @args;
    
      $meta->register_hook(
        foo7 => sub {
          my $build = shift;
          @args = @_;
          die "oops" unless $build->isa('Alien::Build');
          return 'platypus';
        },
      );
      
      $meta->around_hook(
        foo7 => sub {
          my $orig = shift;
          return '(' . $orig->(@_) . ') man';
        }
      );
      
      $meta->around_hook(
        foo7 => sub {
          my $orig = shift;
          return 'the (' . $orig->(@_) . ')';
        }
      );
      
      is( $build->_call_hook('foo7', 1, 2), 'the ((platypus) man)', 'return value' );
      is( \@args, [1,2], 'arguments' );
    
    };
    
    subtest 'alter args' => sub {
    
      my @args;
      
      $meta->register_hook(
        foo8 => sub {
          my $build = shift;
          @args = @_;
          die "oops" unless $build->isa('Alien::Build');
          return 'platypus';
        },
      );
      
      $meta->around_hook(
        foo8 => sub {
          my $orig = shift;
          my $build = shift;
          $orig->($build, map { $_ + 1 } @_);
        }
      );
      
      is( $build->_call_hook('foo8', 1, 2), 'platypus' );
      is( \@args, [ 2,3 ] );
    
    };
  
  };

};

subtest 'probe' => sub {

  subtest 'system' => sub {
  
    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
    
    $meta->register_hook(
      probe => sub {
        note "dir = $CWD";
        return 'system';
      },
    );
    
    is($build->probe, 'system');
    is($build->runtime_prop->{install_type}, 'system');
  
  };
  
  subtest 'share' => sub {

    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
    
    $meta->register_hook(
      probe => sub {
        note "dir = $CWD";
        return 'system';
      },
    );
    
    is($build->probe, 'system');
    is($build->runtime_prop->{install_type}, 'system');
  
  };
  
  subtest 'throw exception' => sub {
  
    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
    
    $meta->register_hook(
      probe => sub {
        note "dir = $CWD";
        die "error will robinson!";
      },
    );
    
    my $type;
    note capture_merged { $type = $build->probe };
    is($type, 'share');
    is($build->runtime_prop->{install_type}, 'share');
  
  };
  
  subtest 'env' => sub {
  
    subtest 'share' => sub {
    
      local $ENV{ALIEN_INSTALL_TYPE} = 'share';
      
      my $build = alienfile filename => 'corpus/blank/alienfile';
      my $meta = $build->meta;
      
      $meta->register_hook(
        probe => sub {
          die "should not get into here!";
        },
      );
      
      is( $build->probe, 'share' );
    
    };
    
    subtest 'system' => sub {
    
      local $ENV{ALIEN_INSTALL_TYPE} = 'system';
    
      subtest 'probe okay' => sub {
      
        my $build = alienfile filename => 'corpus/blank/alienfile';
        my $meta = $build->meta;

        $meta->register_hook(
          probe => sub {
            'system';
          },
        );
        
        is( $build->probe, 'system' );
      
      };
      
      subtest 'probe share' => sub {
      
        my $build = alienfile filename => 'corpus/blank/alienfile';
        my $meta = $build->meta;
        
        $meta->register_hook(
          probe => sub {
            'share';
          }
        );
        
        eval { $build->probe };
        my $error = $@;
        like $error, qr/requested system install not available/;
      
      };
      
      subtest 'probe exception' => sub {
      
        my $build = alienfile filename => 'corpus/blank/alienfile';
        my $meta = $build->meta;
        
        $meta->register_hook(
          probe => sub {
            die "oops!";
          },
        );
        
        eval { $build->probe };
        my $error = $@;
        like $error, qr/oops!/;
      
      };
    
    };

  };
  
};

subtest 'gather system' => sub {

  local $ENV{ALIEN_INSTALL_TYPE} = 'system';

  my $build = alienfile filename => 'corpus/blank/alienfile';
  my $meta = $build->meta;
  
  $meta->register_hook(
    probe => sub {
      'system';
    }
  );
  
  $meta->register_hook(
    gather_system => sub {
      my($build) = @_;
      $build->runtime_prop->{cflags}  = '-DFoo=1';
      $build->runtime_prop->{libs}    = '-lfoo';
      $build->runtime_prop->{version} = '1.2.3';
    },
  );
  
  if($build->install_type eq 'system')
  {
    note capture_merged {
      $build->build;
    };
  }
  
  is(
    $build->runtime_prop,
    hash {
      field cflags  => '-DFoo=1';
      field libs    => '-lfoo';
      field version => '1.2.3';
      etc;
    },
    'runtime props'
  );
  
  is(
    $build->install_prop,
    hash {
      field finished => T();
      field complete => hash {
        field gather_system => T();
        etc;
      };
      etc;
    },
    'install props'
  );

};

subtest 'download' => sub {

  my $build = sub {
    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
    require Alien::Build::Plugin::Fetch::Corpus;
    my $plugin = Alien::Build::Plugin::Fetch::Corpus->new(@_);
    $plugin->init($meta);
    ($build, $meta, $plugin);
  };

  my $tarpath = path('corpus/dist/foo-1.00.tar.gz')->absolute;

  my $check = sub {
    my($build) = @_;

    note scalar capture_merged { $build->download };
     
    is(
      $build->install_prop,
      hash {
        field download => match qr/foo-1.00.tar.gz/;
        field complete => hash {
          field download => T();
          etc;
        };
        etc;
      },
      'install props'
    );
      
    note "build.install_prop.download=@{[ $build->install_prop->{download} ]}";
        
    is(
      path($build->install_prop->{download})->slurp_raw,
      $tarpath->slurp_raw,
      'file matches',
    );
  };  

  subtest 'component' => sub {

    foreach my $file_as (qw( content path ))
    {
  
      subtest "single download with file as $file_as" => sub {
    
        my($build, $meta) = $build->(
          url            => 'http://test1.test/foo/bar/baz/foo-1.00.tar.gz',
          return_file_as => $file_as,
        );
      
        $check->($build);
    
      };
    }
    
    foreach my $listing_as (qw( list html dir_listing ))
    {
    
      subtest "listing download with listing as $listing_as" => sub {
      
        my($build, $meta) = $build->(
          url               => 'http://test1.test/foo/bar/baz/',
          return_listing_as => $listing_as,
        );
        
        $check->($build);
      
      };
    
    }
  
  };
  
  subtest 'command single' => sub {
  
    my $guard = system_fake
      wget => sub {
        my($url) = @_;
        
        # just pretend that we have some hidden files
        path('.foo')->touch;
        
        if($url eq 'http://test1.test/foo/bar/baz/foo-1.00.tar.gz')
        {
          print "200 found $url!\n";
          path('foo-1.00.tar.gz')->spew_raw($tarpath->slurp_raw);
          return 0;
        }
        else
        {
          print "404 not found $url\n";
          return 2;
        }
      };
    
    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
    
    $meta->register_hook(
      download => [ "wget http://test1.test/foo/bar/baz/foo-1.00.tar.gz" ],
    );
    
    $check->($build);
  
  };
  
  subtest 'command no file' => sub {
  
    my $guard = system_fake
      true => sub {
        0;
      };
    
    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
    
    $meta->register_hook(
      download => [ 'true' ],
    );
    
    my($out, $error) = capture_merged { eval { $build->download }; $@ };
    note $out;
    like $error, qr/no files downloaded/, 'diagnostic failure';
  
  };
  
  subtest 'command multiple files' => sub {
  
    my $guard = system_fake
      explode => sub {
        path($_)->touch for map { "$_.txt" } qw( foo bar baz );
        0;
      };
    
    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
    
    $meta->register_hook(
      download => ['explode'],
    );
    
    note scalar capture_merged { $build->download };
    
    is(
      $build->install_prop,
      hash {
        field download => T();
        field complete => hash {
          field download => T();
          etc;
        };
        etc;
      },
      'install props'
    );
    
    my $dir = path($build->install_prop->{download});
    ok(-d $dir, "dir exists");
    ok(-f $dir->child($_), "file $_ exists") for map { "$_.txt" } qw( foo bar baz );
  
  };
  
};

subtest 'extract' => sub {

  my $tar_cmd = do {
    require Alien::Build::Plugin::Extract::CommandLine;
    my $plugin = Alien::Build::Plugin::Extract::CommandLine->new;
    $plugin->tar_cmd;
  };
  
  skip_all 'test requires command line tar' unless $tar_cmd;

  my $build = alienfile filename => 'corpus/blank/alienfile';
  my $meta = $build->meta;
  
  $meta->register_hook(
    extract => [ [ $tar_cmd, "xf", "%{alien.install.download}"] ],
  );
  
  $build->install_prop->{download} = path("corpus/dist/foo-1.00.tar")->absolute->stringify;
  
  my($out, $dir, $error) = capture_merged { (eval { $build->extract }, $@) };
  
  note $out if $out ne '';
  
  is $error, '', 'no exception';
  note $error if $error;
  ok defined $dir && -d $dir, 'directory exists';
  note "dir = $dir";

  foreach my $name (qw( configure foo.c ))
  {
    my $file = path($dir)->child($name);
    ok -f $file, "$name exists";
  }

};

subtest 'build' => sub {

  subtest 'plain' => sub {
    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
  
    my @data;
  
    $meta->prop->{env}->{FOO1} = 'bar1';
    $build->install_prop->{env}->{FOO3} = 'bar3';

    local $ENV{FOO2} = 'bar2';
  
    $meta->register_hook(
      probe => sub { 'share' },
    );
  
    $meta->register_hook(
      extract => sub {
        path('file1')->spew('text1');
        path('file2')->spew('text2');
      },
    );
  
    $meta->register_hook(
      build => sub {
        is $ENV{FOO1}, 'bar1';
        is $ENV{FOO2}, 'bar2';
        is $ENV{FOO3}, 'bar3';
        @data = (path('file1')->slurp, path('file2')->slurp);
      },
    );
    
    my $gather = 0;
    
    $meta->register_hook(
      gather_share => sub {
        $gather = 1;
      },
    );
    
    my $tmp = Path::Tiny->tempdir;
    my $share = $tmp->child('blib/lib/auto/share/Alien-Foo/');
    $build->install_prop->{download} = path("corpus/dist/foo-1.00.tar")->absolute->stringify;
    $build->set_stage($share->stringify);

    note capture_merged {
      $build->build;
      ();
    };
  
    is(
      \@data,
      [ 'text1', 'text2'],
      'build',
    );
    
    is $gather, 1, 'ran gather';
    
    ok( -f $share->child('_alien/alien.json'), 'has alien.json');
    #ok( -f $share->child('_alienfile'), 'has alienfile');
  };
  
  subtest 'destdir' => sub {
  
    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;
  
    $meta->register_hook(
      probe => sub { 'share' },
    );

    $meta->register_hook(
      extract => sub {
        path('file1')->spew('text1');
        path('file2')->spew('text2');
      },
    );
    
    $meta->register_hook(
      build => sub {
        my($build) = @_;
        my $prefix = $build->install_prop->{prefix};

        # Handle DESTDIR in windows, where : may be
        # in install.prefix
        $prefix =~ s!^([a-z]):!$1!i if $^O eq 'MSWin32';

        my $dir = path("$ENV{DESTDIR}/$prefix");
        note "install dir = $dir";
        $dir->mkpath;
        $dir->child($_)->mkpath for qw( bin lib );
        $dir->child('bin/foo')->spew('foo exe');
        $dir->child('lib/libfoo.a')->spew('foo lib');
      },
    );
    
    my $gather = 0;
    
    $meta->register_hook(
      gather_share => sub {
        $gather = 1;
      },
    );
    
    my $tmp = Path::Tiny->tempdir;
   
    my $share = $tmp->child('blib/lib/auto/share/Alien-Foo/');

    $build->meta_prop->{destdir}       = 1;
    $build->install_prop->{download}   = path("corpus/dist/foo-1.00.tar")->absolute->stringify;
    $build->set_prefix($tmp->child('usr/local')->stringify);
    $build->set_stage($share->stringify);
    
    note capture_merged { $build->build };
  
    ok(-d $share, "directory created" );
    
    is $gather, 1, 'ran gather';
    
    ok( -f $share->child('_alien/alien.json'), 'has alien.json');
    ok( -f $share->child('_alien/alienfile'), 'has alienfile');
  
  };
  
};

subtest 'checkpoint' => sub {

  my $root = Path::Tiny->tempdir;

  my $alienfile = Path::Tiny->tempfile( TEMPLATE => 'alienfileXXXXXXX' );
  $alienfile->spew(q{
    use alienfile;
    meta_prop->{foo1} = 'bar1';
  });
  
  subtest 'create checkpoint' => sub {
  
    my $build = Alien::Build->load("$alienfile", root => "$root");
    is($build->meta_prop->{foo1}, 'bar1');
    $build->install_prop->{foo2} = 'bar2';
    $build->runtime_prop->{foo3} = 'bar3';
    $build->checkpoint;
    
    ok( -r path($build->root, 'state.json') );
  
  };
  
  subtest 'resume checkpoint' => sub {
  
    my $build = Alien::Build->resume("$alienfile", "$root");
    is($build->meta_prop->{foo1}, 'bar1');
    is($build->install_prop->{foo2}, 'bar2');
    is($build->runtime_prop->{foo3}, 'bar3');
  
  };

};

subtest 'patch' => sub {

  subtest 'single' => sub {

    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;

    my $tmp = Path::Tiny->tempdir;
    my $share = $tmp->child('blib/lib/auto/share/Alien-Foo/');
    $build->install_prop->{download} = path("corpus/dist/foo-1.00.tar")->absolute->stringify;
    $build->install_prop->{stage}    = $share->stringify;
  
    $meta->register_hook(
      probe => sub { 'share' },
    );
  
    $meta->register_hook(
      extract => sub {
        path('file1')->spew('The quick brown dog jumps over the lazy dog');
        path('file2')->spew('text2');
      },
    );
  
    $meta->register_hook(
      patch => sub {
        # fix the saying.
        path('file1')->edit(sub { s/dog/fox/ });
      },
    );
  
    $meta->register_hook(
      build => sub {
        my($build) = @_;
        path('file1')->copy(path($build->install_prop->{stage})->child('file3'));
      },
    );
  
    note capture_merged {
      $build->build;
      ();
    };
  
    my $file3 = path($build->install_prop->{stage})->child('file3');
    is(
      $file3->slurp,
      'The quick brown fox jumps over the lazy dog',
    );
  };

  subtest 'double' => sub {

    my $build = alienfile filename => 'corpus/blank/alienfile';
    my $meta = $build->meta;

    my $tmp = Path::Tiny->tempdir;
    my $share = $tmp->child('blib/lib/auto/share/Alien-Foo/');
    $build->install_prop->{download} = path("corpus/dist/foo-1.00.tar")->absolute->stringify;
    $build->install_prop->{stage}    = $share->stringify;
  
    $meta->register_hook(
      probe => sub { 'share' },
    );
  
    $meta->register_hook(
      extract => sub {
        path('file1')->spew('The quick brown dog jumps over the lazy dog');
        path('file2')->spew('The quick brown fox jumps over the lazy fox');
      },
    );
  
    $meta->register_hook(
      patch => sub {
        # fix the saying.
        path('file1')->edit(sub { s/dog/fox/ });
      },
    );
    
    $meta->register_hook(
      patch => sub {
        # fix the saying.
        path('file2')->edit(sub { s/fox$/dog/ });
      },
    );
  
    $meta->register_hook(
      build => sub {
        my($build) = @_;
        path('file1')->copy(path($build->install_prop->{stage})->child('file3'));
        path('file2')->copy(path($build->install_prop->{stage})->child('file4'));
      },
    );
  
    note capture_merged {
      $build->build;
      ();
    };
  
    my $file3 = path($build->install_prop->{stage})->child('file3');
    is(
      $file3->slurp,
      'The quick brown fox jumps over the lazy dog',
    );

    my $file4 = path($build->install_prop->{stage})->child('file4');
    is(
      $file4->slurp,
      'The quick brown fox jumps over the lazy dog',
    );
  };

};

subtest 'preload' => sub {

  { package Alien::Build::Plugin::Preload1;
    $INC{'Alien/Build/Plugin/Preload1.pm'} = __FILE__;
    use Alien::Build::Plugin;
    sub init
    {
      my($self, $meta) = @_;
      $meta->register_hook('preload1' => sub {});
    }
  }
  { package Alien::Build::Plugin::Preload1::Preload2;
    $INC{'Alien/Build/Plugin/Preload1/Preload2.pm'} = __FILE__;
    use Alien::Build::Plugin;
    sub init
    {
      my($self, $meta) = @_;
      $meta->register_hook('preload2' => sub {});
    }
  }
  
  local $ENV{ALIEN_BUILD_PRELOAD} = join ';', qw( Preload1 Preload1::Preload2 );
  
  my $build = alienfile filename => 'corpus/blank/alienfile';
  my $meta = $build->meta;
  
  ok( $meta->has_hook($_), "has hook $_" ) for qw( preload1 preload2 );

};

subtest 'first probe returns share' => sub {

  subtest 'share, system' => sub {

    my $build = alienfile q{
      use alienfile;
      probe sub { 'share' };
      probe sub { 'system' };
    };
  
    note capture_merged {
      $build->probe;
    };
  
    is( $build->install_type, 'system' );
  };
  
  subtest 'command ok' => sub {
  
    my $guard = system_fake
      'pkg-config' => sub { 0 }
    ;
  
    my $build = alienfile q{
      use alienfile;
      probe [ [ 'pkg-config', '--exists', 'libfoo' ] ];
    };
    
    note capture_merged {
      $build->probe;
      ();
    };
    
    is($build->install_type, 'system');
  
  };

  subtest 'command bad' => sub {
  
    my $guard = system_fake
      'pkg-config' => sub { 1 }
    ;
  
    my $build = alienfile q{
      use alienfile;
      probe [ [ 'pkg-config', '--exists', 'libfoo' ] ];
    };
    
    note capture_merged {
      $build->probe;
      ();
    };
    
    is($build->install_type, 'share');
  
  };

};

subtest 'system' => sub {

  my @args;

  my $guard = system_fake
    frooble => sub {
      @args = ('frooble', @_);
    },
    xor => sub {
      @args = ('xor', @_);
    },
  ;

  my $build = alienfile q{
    use alienfile;
  };
  
  $build->meta->interpolator->add_helper(
    foo => sub { '1234' },
  );

  $build->meta->interpolator->add_helper(
    bar => sub { 'xor' },
  );
  
  $build->system('frooble', '%{foo}');
  
  is(
    \@args,
    [ 'frooble', '1234' ],
  );
  
  $build->system('%{bar}');
  
  is(
    \@args,
    [ 'xor' ],
  );

};

subtest 'requires pulls helpers' => sub {

  my $build = alienfile q{
    use alienfile;
    requires 'Alien::libfoo1';
    probe sub { 'system' }
  };

  $build->load_requires('any');
  ok($build->meta->interpolator->has_helper('foo1'), 'has helper foo1');
  ok($build->meta->interpolator->has_helper('foo2'), 'has helper foo2');

};

subtest 'around bug?' => sub {

  my $build = alienfile_ok q{
  
    use alienfile;
    
    meta->register_hook(
      foo => sub {
        my($build, $arg) = @_;
        return scalar reverse $arg;
      },
    );
  
  };
  
  is $build->_call_hook(foo => 'bar'), 'rab';

  $build->meta->around_hook(
    foo => sub {
      my($orig, $build, $arg) = @_;
      $orig->($build, "a${arg}b");
    },
  );
  
  is $build->_call_hook(foo => 'bar'), 'braba';

  $build->meta->around_hook(
    foo => sub {
      my($orig, $build, $arg) = @_;
      $orig->($build, "|${arg}|");
    },
  );
  
  is $build->_call_hook(foo => 'bar'), 'b|rab|a';

};

subtest 'requires of Alien::Build or Alien::Base' => sub {

  subtest 'Alien::Build' => sub {
  
    my $build = alienfile_ok q{
      use alienfile;
      requires 'Alien::Build' => 0;
    };
    
    eval {
      $build->load_requires('configure');
      $build->load_requires('share');
    };
    
    is $@, '';
    
  };

  subtest 'Alien::Base' => sub {
  
    my $build = alienfile_ok q{
      use alienfile;
      requires 'Alien::Base' => 0;
    };
    
    eval {
      $build->load_requires('configure');
      $build->load_requires('share');
    };
    
    is $@, '';
    
  };

};

done_testing;

{
  package MyBuild;
  use base 'Alien::Build';
}

