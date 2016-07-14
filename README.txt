Tinkertoy Model
---------------

The Tinkertoy Model is a small scalable agent simulation based on work by 
Shoham & Tennenholtz (1997).
 
Requirements
------------

The following modules are required for the Tinkertoy Model to run,

  Carp
  Config::Simple
  Config::User
  Data::Dumper
  Errno
  Fcntl
  File::Spec
  IO::Socket
  Net::Domain
  POSIX

they are either distributed with Perl or can be found on CPAN.

Usage
-----

A typical session would be,

  % cd bin
  % /usr/bin/perl populate.pl -pool 20
  % /usr/bin/perl simulation.pl -iter 100 -loop 5
  % /usr/bin/perl kill.pl

here we start 20 agent processes. We then use these 20 agents in 5 seperate
simulations, where each simulation runs for 100 iterations.

Authors
-------

The tinkertoy model was written by Alasdair Allan <aa@astro.ex.ac.uk>.

References
----------

"On emergence of social conventions: modelling, analysis and simulations",
Shoham, Y., Tennenholtz, M., 1997, Artificial Intelligence, pp. 139-166
