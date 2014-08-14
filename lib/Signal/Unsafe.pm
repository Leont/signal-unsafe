package Signal::Unsafe;
use strict;
use warnings FATAL => 'all';

use XSLoader;
XSLoader::load(__PACKAGE__, Signal::Unsafe->VERSION);

use Config;
use IPC::Signal qw/sig_num sig_name/;
use List::Util 'reduce';
use POSIX qw/SA_SIGINFO/;

{
no warnings 'once';
tie %Signal::Unsafe, __PACKAGE__;
}
our $Flags = SA_SIGINFO;
our $Mask  = POSIX::SigSet->new;

my $sig_max = $Config{sig_count} - 1;

sub TIEHASH {
	my $class = shift;
	my $self = { iterator => 1, };
	return bless $self, $class;
}

sub _get_status {
	my ($self, $num) = @_;
	my $ret = POSIX::SigAction->new;
	sigaction($num, undef, $ret);
	return [ $ret->handler, $ret->flags, $ret->mask ];
}

sub FETCH {
	my ($self, $key) = @_;
	return $self->_get_status(sig_num($key));
}

my %flag_values = (
	siginfo   => POSIX::SA_SIGINFO,
	nodefer   => POSIX::SA_NODEFER,
	restart   => POSIX::SA_RESTART,
	onstack   => POSIX::SA_ONSTACK,
	resethand => POSIX::SA_RESETHAND,
	nocldstop => POSIX::SA_NOCLDSTOP,
	nocldwait => POSIX::SA_NOCLDWAIT,
);

sub get_args {
	my $value = shift;
	if (ref $value eq 'ARRAY') {
		my ($handler, $flags, $mask) = @{$value};
		$mask = $Mask if not defined $mask;
		$flags = not defined $flags ? $Flags : ref($flags) ne 'ARRAY' ? $flags : reduce { $a | $b } map { $flag_values{$_} } @{$flags};
		return ($handler, $mask, $flags);
	}
	else {
		return ($value, $Flags, $Mask);
	}
}

sub STORE {
	my ($self, $key, $value) = @_;
	my ($handler, $flags, $mask) = get_args($value);
	sigaction(sig_num($key), POSIX::SigAction->new($handler, $mask, $flags));
	return;
}

sub DELETE {
	my ($self, $key) = @_;
	my $old = POSIX::SigAction->new("DEFAULT", $Mask, $Flags);
	sigaction(sig_num($key), POSIX::SigAction->new("DEFAULT", $Mask, $Flags), $old);
	return ($old->handler, $old->mask, $old->flags);
}

sub CLEAR {
	my ($self) = @_;
	for my $sig_no (1 .. $sig_max) {
		sigaction($sig_no, POSIX::SigAction->new("DEFAULT", $Mask, $Flags));
	}
	return;
}

sub EXISTS {
	my ($self, $key) = @_;
	return defined sig_num($key);
}

sub FIRSTKEY {
	my $self = shift;
	$self->{iterator} = 1;
	return $self->NEXTKEY;
}

sub NEXTKEY {
	my $self = shift;
	if ($self->{iterator} <= $sig_max) {
		my $num = $self->{iterator}++;
		return wantarray ? (sig_name($num) => $self->_get_status($num)) : sig_name($num);
	}
	else {
		return;
	}
}

sub SCALAR {
	return 1;
}

sub UNTIE {
	my $self = shift;
	$self->CLEAR;
	return;
}

sub DESTROY {
}

1;

#ABSTRACT: Unsafe signal handlers made easy

__END__

