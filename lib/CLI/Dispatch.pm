package CLI::Dispatch;

use strict;
use warnings;
use Getopt::Long ();
use String::CamelCase;

our $VERSION = '0.02';

# you may want to override these three methods.

sub options {qw( help|h|? verbose|v )}

sub default_command { 'help' }

sub get_command {
  my $class = shift;

  my $command = shift @ARGV || $class->default_command;
  return $class->convert_command($command);
}

sub convert_command {
  my ($class, $command) = @_;

  $command = String::CamelCase::camelize( $command );
  $command =~ tr/a-zA-Z0-9_//cd;
  return $command;
}

# you usually don't need to care below.

sub get_options {
  my ($class, @specs) = @_;

  my $parser = Getopt::Long::Parser->new(
    config => [qw( bundling ignore_case pass_through )]
  );

  $parser->getoptions( \my %hash => @specs );

  return %hash;
}

sub load_command {
  my ($class, $namespace, $help) = @_;

  my $command = $class->get_command;

  if ( $help ) {
    unshift @ARGV, $command;
    $command = 'Help';
  }

  my $instance = $class->_load_command($namespace, $command);
  return $instance if $instance;

  # fallback to help (maybe the command is just a pod)
  unshift @ARGV, $command;
  $instance = $class->_load_command($namespace, 'Help');
  return $instance if $instance;

  # this shouldn't happen
  print STDERR "Help command is missing or broken.\n";
  print STDERR "Prerequisite modules may not be installed.\n";
  print STDERR "Please check your installation.\n";
  exit;
}

sub _load_command {
  my ($class, $namespace, $command) = @_;

  my $package = $namespace.'::'.$command;
  eval "require $package";
  return $package->new unless $@;
  if ( $@ =~ /Can't locate/ ) {
    $package = __PACKAGE__.'::'.$command;
    eval "require $package";
    return $package->new unless $@;
  }
  return;
}

sub run {
  my ($class, $namespace) = @_;

  $namespace ||= $class;

  my %global  = $class->get_options( $class->options );
  my $command = $class->load_command( $namespace, $global{help} );
  my %local   = $class->get_options( $command->options );

  $command->set_options( %global, %local, _namespace => $namespace );

  if ( $command->isa('CLI::Dispatch::Help') and @ARGV ) {
    $ARGV[0] = $class->convert_command($ARGV[0]);
  }

  $command->run(@ARGV);
}

1;

__END__

=head1 NAME

CLI::Dispatch - simple CLI dispatcher

=head1 SYNOPSIS

  * Basic usage

  In your script file (e.g. script.pl):

    #!/usr/bin/perl
    use strict;
    use lib 'lib';
    use CLI::Dispatch;
    CLI::Dispatch->run('MyScript');

  And in your "command" file (e.g. lib/MyScript/DumpMe.pm):

    package MyScript::DumpMe;
    use strict;
    use base 'CLI::Dispatch::Command';
    use Data::Dump;

    sub run {
      my ($self, @args) = @_;

      @args = $self unless @args;

      # do something
      print $self->{verbose} ? Data::Dump::dump(@args) : @args;
    }
    1;

  From the shell:

    > perl script.pl dump_me "some args" --verbose

    # will dump "some args"

  * Advanced usage

  In your script file (e.g. script.pl):

    #!/usr/bin/perl
    use strict;
    use lib 'lib';
    use MyScript;
    MyScript->run;

  And in your "dispatcher" file (e.g. lib/MyScript.pm):

    package MyScript;
    use strict;
    use base 'CLI::Dispatch';

    sub options {qw( help|h|? verbose|v stderr )}
    sub get_command { shift @ARGV || 'Help' }  # no camelization

    1;

  And in your "command" file (e.g. lib/MyScript/escape.pm):

    package MyScript::escape;
    use strict;
    use base 'CLI::Dispatch::Command';

    sub options {qw( uri )}

    sub run {
      my ($self, @args) = @_;

      if ( $self->{url} ) {
        require URI::Escape;
        print URI::Escape::uri_escape($args[0]);
      }
      else {
        require HTML::Entities;
        print HTML::Entities::encode_entities($args[0]);
      }
    }
    1;

  From the shell:

    > perl script.pl escape "query=some string!?" --uri

    # will print a uri-escaped string

=head1 DESCRIPTION

L<CLI::Dispatch> is a simple CLI dispatcher. Basic usage is almost the same as the one of L<App::CLI>, but you can omit a dispatcher class if you don't need to customize. Command/class mapping is slightly different, too (ucfirst for L<App::CLI>, and camelize for L<CLI::Dispatch>). And unlike L<App::Cmd>, L<CLI::Dispatch> dispatcher works even when some of the subordinate commands are broken for various reasons (unsupported OS, lack of dependencies, etc). Those are the main reasons why I reinvent the wheel.

See L<CLI::Dispatch::Command> to know how to write an actual command class.

=head1 METHODS

=head2 run

takes an optional namespace, and parses @ARGV to load an appropriate command class, and run it with options that are also parsed from @ARGV. As shown in the SYNOPSIS, you don't need to pass anything when you create a dispatcher subclass, and vice versa.

=head2 options

specifies an array of global options every command should have. By default, C<help> and C<verbose> (and their short forms) are registered. Command-specific options should be placed in each command class.

=head2 default_command

specifies a default command that will run when you don't specify any command (when you run a script without any arguments). C<help> by default.

=head2 get_command

usually looks for a command from @ARGV (after global options are parsed), transforms it if necessary (camelize by default), and returns the result.

If you have only one command, and you don't want to specify it every time when you run a script, let this just return the command:

  sub get_command { 'JustDoThis' }

Then, when you run the script, C<YourScript::JustDoThis> command will always be executed (and the first argument won't be considered as a command).

=head2 convert_command

takes a command name, transforms it if necessary (camelize by default), and returns the result.

=head2 get_options

takes an array of option specifications and returns a hash of parsed options. See L<Getopt::Long> for option specifications.

=head2 load_command

takes a namespace, and a flag to tell if the C<help> option is set or not, and loads an appropriate command class to return its instance.

=head1 SEE ALSO

L<App::CLI>, L<App::Cmd>, L<Getopt::Long>

=head1 AUTHOR

Kenichi Ishigaki, E<lt>ishigaki@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Kenichi Ishigaki.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
