#!/Software/perl-5.8.8/bin/perl

  use strict;
  use warnings;
  use vars qw/$VERSION $LOOP $ITERATIONS/;

  $VERSION = 1.0;
  $ITERATIONS = 50;   # Total number of iterations to run during simulation
  $LOOP = 1;          # Total number of times we're going to run the simulation
  
  use lib "../lib/perl5";
  use Agent::Util qw/:all/;
  use Carp;
  use Getopt::Long;

  unless( scalar @ARGV >= 1 ) {
     die "USAGE: $0 -iter integer -loop integer\n";
  }
  my $status = GetOptions( "iter=s"  => \$ITERATIONS,
                           "loop=s"  => \$LOOP );
  
  my $agents = Agent::Util::number_of_agents();
  print "There are $agents agents in the pool\n";
  if ( $agents <= 2 ) {
     croak( "There are too few agents running to start the simulation" );
  }

  print "Reinitalising agents for simulation run...\n\n";
  Agent::Util::reset_agents();

  print "Tinkertoy Model\n";
  print "===============\n";
  my @simulation_results;
  foreach my $i ( 1 ... $LOOP ) {
 
     my $converge = run_simulation( $i );
     
     print "Pushing result to stack...\n";
     push @simulation_results, $converge;
    
     unless ( $i == $LOOP ) {
        print "Reinitalising agents for simulation run...\n";
        Agent::Util::reset_agents(); 
     }
  }
  
  my $counter = 0;
  foreach my $j ( 0 ... $#simulation_results ) {
     $counter = $counter + 1 if $simulation_results[$j] > 95.0;
  }
  
  print "\nFinal Results\n";
  print "=============\n";
  print "Simulation reached 95% convergence in $counter of $LOOP";
  print " runs, or " . ( 100.0*($counter/$LOOP) ) . "% of all cases.\n";
  print "Each simulation had $agents agents and ran for $ITERATIONS plays.\n";

  exit;
  
  # --------------------------------------------------------------------------

  sub run_simulation {
    my $instance = shift;
    print "\nRunning simulation ($instance)\n";
    print "------------------\n";
    
    # poll inital state of agents in pool ------------------------------------

    my ( $converge, $coop_count, $defect_count ) = agent_status();
    print "Agents = $agents, Cooperate = $coop_count, Defect = $defect_count, ";
    print "Convergence = $converge %\n\n";    
     
    # run simulation ---------------------------------------------------------
    foreach my $i ( 1 ... $ITERATIONS ) {
     
      #print "Picking random agents from pool\n";
      my $first = Agent::Util::pick_random_agent();
      my $second = Agent::Util::pick_random_agent();
      while ( $first == $second ) {
    	 $second = Agent::Util::pick_random_agent();
      }
      print "Play $i: Agent $first vs. $second\n";
      
      my $response = start_play( $first, $second);
      #print "Result $response\n";
      
    }
    
    # poll final state of agents in pool -------------------------------------

    ( $converge, $coop_count, $defect_count ) = agent_status();
    print "\n";
    print "Agents = $agents, Cooperate = $coop_count, Defect = $defect_count, ";
    print "Convergence = $converge %\n";    
    
    append_to_results_file( $agents, $coop_count, $defect_count, $converge );
    return $converge;
      
  }
  
  # --------------------------------------------------------------------------
 
  sub start_play {
     my $number = shift;
     my $target = shift;
     
     my $response;
     eval { $response = Agent::Util::send_message($number, "agent $target"); };
     if( $@ ) {
        carp( "Can not contact agent($number)" );
     }   
     return $response;
  }
  
  sub agent_status {
  
    my @status = Agent::Util::poll_agents();
    my $coop_count = 0;
    my $defect_count = 0;
    foreach my $j ( 0 ... $#status ) {
      $coop_count = $coop_count + 1 if $status[$j] eq "cooperate";
      $defect_count = $defect_count + 1 if $status[$j] eq "defect";
    }
    my $converge;
    if ( $coop_count > $defect_count ) {
      $converge = 100*( $coop_count / $agents );
    } else {
      $converge = 100*( $defect_count / $agents );
    }

    return ( $converge, $coop_count, $defect_count );
  }
  
    
  sub append_to_results_file {
     my ( $agents, $coop_count, $defect_count, $converge) = @_;
     
     my $dir = File::Spec->catdir( Config::User->Home(), );
     my $file = File::Spec->catfile( $dir, ".tinkertoy.results" );
     unless( open( RESULTS, ">>$file" ) ){
        croak( "Can not open $file for append access" );
     }
     		      	     
     # write to log file
     print RESULTS 
        "$agents $ITERATIONS $coop_count $defect_count $converge\n";
     close RESULTS;
  }

  # --------------------------------------------------------------------------
