#!/Software/perl-5.8.8/bin/perl
 
  use strict;
  use warnings;
  use vars qw/$VERSION $ITERATIONS $POOL/;

  $VERSION = 1.0;
  $POOL = 5;          # Total number of agents in pool (default 5)
  
  use lib "../lib/perl5";
  use Agent::Util qw/:all/;
  use Carp;
  use Getopt::Long;
  use IO::Socket;
  use Net::Domain qw(hostname hostdomain);
  use POSIX qw/:sys_wait_h/;
  use Errno qw/EAGAIN/;

  unless( scalar @ARGV >= 1 ) {
     die "USAGE: $0 -pool integer\n";
  }

  my $status = GetOptions( "pool=s"  => \$POOL );

  # populate the agent pool ------------------------------------------------

  # grab the list of existing agents
  my $dir = File::Spec->catfile( Config::User->Home(), ".tinkertoy" );
  unless( opendir(DIR, $dir ) ) {
     mkdir $dir, 0755;
     if( opendir(DIR, $dir ) ) {
        closedir DIR;
     } else {
        croak( "Can not create directory $dir" );
     }
  }
  closedir DIR;
  my $number = Agent::Util::number_of_agents(); 

  # fork processes
  print "Forking agent processes...\n";
  my $not_started = 0;
  foreach my $k ( 1 ... $POOL ) {
     sleep( 1 );
     print "Forking agent " . ($k) . "\n";
     my $status = Agent::Util::fork_agent();
     if ( $status != 1 ) {
        $not_started = $not_started + 1;
     }	 
  }
  
  if ( $not_started == $POOL ) {
     print "No additional processes have been started.\n";
     exit;
  } elsif ( $not_started > 0) {
     print "Failed to start $not_started of $POOL requested processes\n";
     print "Waiting for remaining process start...\n";
  } else {
     print "Waiting for processes to start...\n";
  }      

  # we're going to add $POOL agents to this total, so update total
  my $agents = 0;    
  $agents = $number if defined $number;
  $POOL = $POOL + $agents if defined $agents;

  # wait while they're spawned (can hang?)
  while ( $agents != ($POOL - $not_started) ) {
     my @files = Agent::Util::list_of_agents( ); 
     $agents = scalar( @files );
     print "Pool of $agents agents (waiting for expected " . 
           ($POOL-$not_started) . ")\n";
     sleep 1; 
  }

  # append (or create) a list of PIDs for these processes
  my @pids = Agent::Util::pids_of_agents( );  
  file_of_pids( \@pids );
  print "There are " . ($POOL-$not_started) . " agents running...\n";

  # ------------------------------------------------------------------------
  
  sub file_of_pids {
     my $pids = shift;
     
     my $dir = File::Spec->catdir( Config::User->Home(), );
     my $file = File::Spec->catfile( $dir, ".tinkertoy.pids" );
     unless( open( PIDFILE, ">$file" ) ){
        croak( "Can not open $file for write access" );
     }
     		      	     
     # write to log file
     foreach my $i ( 0 ... $#$pids ) {
        print PIDFILE "$pids[$i]\n";
     }
     close PIDFILE;
  }

  
     
