#!/Software/perl-5.8.8/bin/perl

  use strict;
  use warnings;
  use vars qw/$VERSION/;

  $VERSION = 1.0;
  
  use Carp;
  use Config::User;
  use File::Spec;

  print "Cleaning up agent processes...\n";
  
  my @pids = get_pids();
  foreach my $k ( 0 ... $#pids ) {
     chomp( $pids[$k] );
     print "Killing agent process $pids[$k]\n";
     kill 'TERM', $pids[$k];
  }
  print "Killed " . scalar(@pids) . " processes.\n";
  print "Unlinking PID file...\n";
  unlink_pid_file();
  exit;
  
  # ------------------------------------------------------------------------
  
  
  sub get_pids {
     
     my $dir = File::Spec->catdir( Config::User->Home(), );
     my $file = File::Spec->catfile( $dir, ".tinkertoy.pids" );
     unless( open( PIDFILE, "<$file" ) ){
        print "Can not open $file for read access (no agents running?)\n";
	exit;
     }
     
     my @list = <PIDFILE>;
     close (PIDFILE);				  
     return @list;
     
  } 
  
  sub unlink_pid_file {

     my $dir = File::Spec->catdir( Config::User->Home(), );
     my $file = File::Spec->catfile( $dir, ".tinkertoy.pids" );  
     unless( unlink $file ) {
        carp( "Can not delete $file during cleanup" );  	 
     }
  
  
  }   
