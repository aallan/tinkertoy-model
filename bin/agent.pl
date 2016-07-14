#!/Software/perl-5.8.8/bin/perl

  use strict;
  use warnings;
  use vars qw/$VERSION $SCORE $STRATEGY @HISTORY/;
  
  use sigtrap 'handler', \&stop, 'normal-signals';
  use sigtrap 'handler', \&stop, 'error-signals';
  $SIG{'PIPE'} = 'IGNORE';
  
  $VERSION = 1.0;
  
  use lib "../lib/perl5";
  use Agent::Util qw/:all/;
  use IO::TCP::Server qw/:all/;
  use Carp;
  use Data::Dumper;
  
  # inital starting strategy determined randomly
  my $random = rand;
  $STRATEGY = "cooperate" if $random > 0.5;
  $STRATEGY = "defect" if $random < 0.5; 
  print "Inital strategy is to $STRATEGY\n";
  
  # inital SCORE
  $SCORE = 0;
  
  # start server
  my $server = new IO::TCP::Server( Dir => "tinkertoy" );
  print "Starting agent(" . $server->id() . ") on " .
        $server->host() . ":" . $server->port() . "\n";
  
  # listen for messages
  my ( $listen, $buffer );
  while ( $listen = $server->socket()->accept() ) {
      
      # read incoming message from socket
      my $length;
      my $bytes_read = sysread( $listen, $length, 4 );
      $length = unpack( "N", $length );
      $bytes_read = sysread( $listen, $buffer, $length);
      #print "RX: $buffer ($length bytes)\n";  
      
      # handle message
      my $response = handle( $buffer );
            
      # return an ACK message to client
      my $return_bytes = pack( "N", length( $response ) );
      #print "TX: $response (" . length($response) . " bytes)\n";      
      print "Sending $response\n";
      
      print $listen $return_bytes;
      $listen->flush();
      print $listen $response;
      $listen->flush();
      close ($listen);
  }   
  exit;                                     
  
  # ------------------------------------------------------------------------

  # handle incoming messages
  sub handle {
     my $message = shift;
       
  # ping -------------------------------------------------------------------
     if ( $message eq "ping" ) {
       print "\nRecieved PING message (responding)\n";
       return "$STRATEGY";
       
  # agent ------------------------------------------------------------------
     } elsif ( $message =~ "agent" ) {
       print "\nRecieved AGENT message (starting play)\n";
       my ( $word, $number ) = split( / /, $message );

       # make a decsion of our own
       my $decision;
       if ( $STRATEGY eq "cooperate" ) {
          $decision = 1;
       } else {
          $decision = 0;
       }
       
       # send message to opponent
       my $response;
       eval { $response = Agent::Util::send_message( $number, "play" ); };
       if( $@ ) {
          carp( "Can not contact agent($number)" );
       }  
       
       # update own score and push opponents decison onto history stack
       my $update;
       if ( $response == $decision ) {
          $update = 1;
       } else {
          $update = -1;
       }	  	  
       $SCORE = $SCORE + $update;
       push @HISTORY, $response;
       
       # update opponent on outcome
       eval { my $ack = Agent::Util::send_message($number, "update $update"); };
       if( $@ ) {
          carp( "Can not contact agent($number)" );
       }         
      
       # decide whether to change strategy
       change_strategy();
      
       print "Decision $decision, Response $response, Score $SCORE\n";
       return "$decision $response $SCORE";
       
  # play -------------------------------------------------------------------
     } elsif ( $message eq "play" ) {
       print "\nRecieved PLAY message (making decsion)\n";
       # make decision
       my $decision;
       if ( $STRATEGY eq "cooperate" ) {
          print "Strategy is cooperate, return 1\n";
          $decision = 1;
       } else {
          print "Strategy is defect, return 0\n";
          $decision = 0;
       }
       return $decision;
     
  # update -----------------------------------------------------------------
     } elsif ( $message =~ "update" ) {
       print "\nRecieved UPDATE message (seeing result)\n";
        # update score based on opponents decsion
	my ( $word, $update ) = split( / /, $message );
	$SCORE = $SCORE + $update;
        if( $STRATEGY eq "cooperate" ) {
	   if ( $update == -1 ) {
	      push @HISTORY, 0;
	   } else {   
	      push @HISTORY, 1;
	   }   
	} else {
	   if ( $update == -1 ) {
	      push @HISTORY, 1;
	   } else {   
	      push @HISTORY, 0;
	   }   
	}      
        
	# decide whether to change strategy
	change_strategy();
	
        print "Update $update, Score $SCORE\n";
        return "ack";

  # reset ------------------------------------------------------------------
     } elsif ( $message eq "reset" ) {
       print "\nRecieved RESET message (reseting to inital conditions)\n";
       	
	# inital starting strategy determined randomly
        my $random = rand;
        $STRATEGY = "cooperate" if $random > 0.5;
        $STRATEGY = "defect" if $random < 0.5; 
        print "Resetting strategy to $STRATEGY\n";
	@HISTORY = ();
	print "Emptying HISTORY\n";
	
	return "ack"
	
  # unknown ----------------------------------------------------------------
     } else {
       print "\nRecieved UNKONWN message (confused)\n";
       return "unknown";
     }    
     
  }
  
  # decide whether we change strategy
  sub change_strategy {
    
    # check decision against history
    my $current_total = 0;
    my $alternate_total = 0;
    for my $i ( 0 ... $#HISTORY ) {
       #print "$i: $HISTORY[$i]\n";
       if ( $STRATEGY eq "cooperate" ) {
    	  if ( $HISTORY[$i] == 1 ) {
    	     #print "$HISTORY[$i] == 1\n";
    	     $current_total = $current_total + 1;
    	     $alternate_total = $alternate_total - 1;
    	  } else {
    	     #print "$HISTORY[$i] == 0\n";
    	     $current_total = $current_total - 1;
    	     $alternate_total = $alternate_total + 1;
    	  }
    	  
       } else {
    	  if ( $HISTORY[$i] == 0 ) {
    	     #print "$HISTORY[$i] == 0\n";
    	     $current_total = $current_total + 1;
    	     $alternate_total = $alternate_total - 1;
    	  }  else {
    	     #print "$HISTORY[$i] == 1\n";
    	     $current_total = $current_total - 1;
    	     $alternate_total = $alternate_total + 1;
    	  }	     
       }      
    }

    # change strategies if we're using the wrong one
    print "Current Strategy $current_total\n";
    print "Alternative Strategy $alternate_total\n";
    if ( $alternate_total > $current_total ) {
       if ( $STRATEGY eq "cooperate" ) {
    	  $STRATEGY = "defect";
       } else {   
    	  $STRATEGY = "cooperate";
       }   
       print "Changing strategy to $STRATEGY\n";
    } else {
       print "Current strategy is best option\n";
    }  
    
  }
  
  # shutdown the server
  sub stop {
    print "Shutting down server...\n";
    $server->cleanup();
  }
  
  
