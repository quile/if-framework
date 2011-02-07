# Copyright (c) 2010 - Action Without Borders
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

package IF::System::Process;

# System Process Runner - used esp. in appCtl

use strict;
use POSIX;
use Time::HiRes qw(usleep);
use Term::ANSIColor qw(:constants);

our $DEBUG=0;

# needsPidFile determines if this module takes care of generating
# a pid file, or if the process does it itself (as httpd and searchServer do)
#
#  the pid file will always be   ${procName}.pid

sub new {
	my $classname = shift;
	my $props = shift;

	my $self = $props;
	$self->{pidFile} = $self->{pidPath}."/".$self->{name}.".pid";

	return bless $self, $classname;
}

sub run {
	my $self = shift;
	my $sigset;
	my $pid;
	my $oldPid;

	print YELLOW, "\nRUN: $self->{name}\n", RESET;
	print "- running $self->{name} as $self->{bin} $self->{args}\n" if $DEBUG;

	if ($oldPid = $self->readPid()) {
		if ($self->processIsRunning($oldPid)) {
			print "- $self->{name} is running under pid ($oldPid)\n";
			return undef;
		} else {
			$self->deletePid();
			print "- stale pid file ($oldPid) deleted\n";
		}
	}

   # block signal for fork
    $sigset = POSIX::SigSet->new(SIGINT);
    sigprocmask(SIG_BLOCK, $sigset) or die "Can't block SIGINT for fork: $!";

    die "fork: $!" unless defined ($pid = fork());

    if ($pid) {
        # This is the parent
        sigprocmask(SIG_UNBLOCK, $sigset) or die "Can't unblock SIGINT for fork: $!";

		if ($self->{writePidFile}) {
			$self->writePid($pid);
		}
		print GREEN, "+ $self->{name} running ($pid)\n", RESET;

        return;
    } else {
        # DO NOT RETURN AFTER THIS
        $SIG{INT} = 'DEFAULT';

        sigprocmask(SIG_UNBLOCK, $sigset) or die "Can't unblock SIGINT for fork: $!";

		print "$self->{bin} $self->{args}\n" if $DEBUG;
		exec("$self->{bin} $self->{args}") or
		  print RED,"! exec of $self->{bin} failed.\n",RESET;

		# never gets here...
    }

}

# could subclass this for httpd and use it's more graceful restart mechanisms.....
sub restart {
	my $self = shift;

	return unless $self->halt();
	sleep 5;
	$self->run();
	return;
}

sub halt {
	my $self = shift;
	my $killCounter = 0;

	print YELLOW, "\nHALT $self->{name}\n", RESET;

	my $pid = $self->readPid();  # arg says to throw an error msg if the pid is not found
	unless ($pid) {
		print "- no pid found for $self->{name} at $self->{pidFile}.\n";
		return undef;
	}
	kill 15, $pid;
	usleep(100000);	# 100 ms

	if ($self->processIsRunning($pid) and not $self->userCanKillProcess($pid)) {
		print RED,"! user does not have permission to kill $self->{name} ($pid)\n",RESET;
		return undef;
	}

	# kill with a 0 signal will return true if the proc is running, undef otherwise
	print "- waiting for $self->{name} ($pid) to finish ";
	$| = 1;
	while ($self->processIsRunning($pid)) {
		print ".";
		usleep (500000);
		if ($killCounter++ > 20) {
			print "\n! proc didn't respond to TERM, trying KILL\n";
			kill 9, $pid;
			usleep(1000000);
		}
	}

	if (! $self->processIsRunning($pid)) {
		print GREEN,"\n+ $self->{name} ($pid) stopped.\n",RESET;
		$self->deletePid();
	} else {
		print RED,"\n! failed to stop $self->{name} ($pid).\n",RESET;
		return;
	}
	return 1; # 1 indicating success
}

sub checkConfig {
	my $self = shift;
	my $verbose = shift;

	return 1 unless exists $self->{configTestArgs};
	print YELLOW, "\nCHECK CONFIG: $self->{name}\n", RESET if $verbose;

	my $cmd = join(' ',($self->{bin}, $self->{configTestArgs}, $self->{args}));
	my $retval = system($cmd);
	if ($retval == -1) {
		print RED,"\n! failed to run $self->{name} ($cmd) for config check: $!\n",RESET;
		return;
	}
	if ($retval != 0) {
		print RED,"\n! broken config for $self->{name}.\n",RESET;
		print `$cmd`;
		return;
	} else {
		print GREEN,`$cmd`,RESET if $verbose;
	}
	return 1; # 1 indicating success
}

sub debug {
	my $self = shift;
	my $oldPid;

	print YELLOW, "\nDEBUG $self->{name}\n", RESET;

#   do {print RED,"! $self->{bin} has no debug args.\n",RESET; return; } unless $self->{debugArgs};

	if ($oldPid = $self->readPid()) {
		if ($self->processIsRunning($oldPid))  {
			print RED, "- pocess is already running ($oldPid), can't debug - stop it first\n",RESET;
			return 0;
		} else {
			$self->deletePid();
			print "- stale pid file ($oldPid) deleted\n";
		}
	}

	exec("$self->{bin} $self->{debugArgs}") || do {
		  print RED,"! exec of $self->{bin} failed.\n",RESET;
		  return 0;
		};

	return 1;
}


sub readPid {
	my $self = shift;

	open PIDFILE, "< $self->{pidFile}" or return undef;
	my $pid = <PIDFILE>;

	chomp $pid;
	close PIDFILE;
	return $pid;
}

sub writePid {
	my $self = shift;
	my $pid = shift;

	open PIDFILE, "> $self->{pidFile}" or
		print "! can't write $self->{pidFile}.\n";
	print PIDFILE $pid;
	close PIDFILE;
	return;
}


# is there actually a process corresponding to the pid?
sub processIsRunning {
	my $self = shift;
	my $pid = shift;

	# a signal of 0 checks to see if the proc exist
	if (kill 0, $pid) {
		return 1;
	} else {
		my $err = POSIX::errno();
		# no such process, that's fine
		return undef if $err == 3;
		return 1;
	}
}

sub userCanKillProcess {
	my $self = shift;
	my $pid = shift;

	# a signal of 0 checks to see if the proc exist
	if (kill 0, $pid) {
		return 1;
	} else {
		my $err = POSIX::errno;
		# no such process, that's fine
		return 1 if $err == 3;
		return undef;
	}
}

sub deletePid {
	my $self = shift;

	return unless -f $self->{pidFile};
	unlink $self->{pidFile} or print "! error deleting $self->{pidFile}\n";
	return 1;
}

1;
