use Module::Build;
my $build = Module::Build->new
( module_name        => "Test::LectroTest",
  license            => "perl",
  create_makefile_pl => "traditional",
  create_readme      => 1,
  requires           => { Filter::Util::Call => 0,
                          Class::Struct => 0, Data::Dumper => 0,
                          Carp => 0, Test::Builder => 0
                        },
  build_requires     => { File::Temp => 0, Test::More => 0,
                        },
);

$build->create_build_script;
