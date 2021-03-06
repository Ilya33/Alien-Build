use Test::Alien::CanCompile;
use Test2::V0 -no_srand => 1;
use Test::Alien;

is(
  intercept { xs_ok '' },
  array {
    event Ok => sub {
      call pass => F();
      call name => 'xs';
    };
    event Diag => sub {};
    event Diag => sub {
      call message => '  XS does not have a module decleration that we could find';
    };
    end;
  },
  'xs with no module'
);

is(
  intercept { xs_ok '', sub { } },
  array {
    event Ok => sub {
      call pass => F();
      call name => 'xs';
    };
    event Diag => sub {};
    event Diag => sub {
      call message => '  XS does not have a module decleration that we could find';
    };
    event Subtest => sub {
      call buffered  => T();
      call subevents => array {
        event Plan => sub {
          call max       => 0;
          call directive => 'SKIP';
          call reason    => 'subtest requires xs success';
        };
        end;
      };
    };
    end;
  },
  'xs fail with subtest'
);

# TODO: test that parsexs error should fail

is(
  intercept { xs_ok "this should cause a compile error\nMODULE = Foo::Bar PACKAGE = Foo::Bar\n" },
  array {
    event Ok => sub {
      call pass => F();
      call name => 'xs';
    };
    event Diag => sub {};
    event Diag => sub {
      call message => '  ExtUtils::CBuilder->compile failed';
    };
    etc;
  },
  'xs with C compile error'
);

# TODO: test that link error should fail

my $xs = do { local $/; <DATA> };
xs_ok { xs => $xs, verbose => 1 }, with_subtest {
  my($module) = @_;
  is $module->baz(), 42, "call $module->baz()";
};

$xs =~ s{\bTA_MODULE\b}{Foo::Bar}g;
xs_ok $xs, 'xs without parameterized name', with_subtest {
  my($module) = @_;
  is $module, 'Foo::Bar';
  is $module->baz(), 42, "call $module->baz()";
};

done_testing;

__DATA__

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

int baz(const char *class)
{
  return 42;
}

MODULE = TA_MODULE PACKAGE = TA_MODULE

int baz(class);
    const char *class;
  
