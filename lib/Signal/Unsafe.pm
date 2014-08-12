package Signal::Unsafe;
use strict;
use warnings FATAL => 'all';

use XSLoader;
XSLoader::load(__PACKAGE__, Signal::Unsafe->VERSION);

use Config;
use IPC::Signal qw/sig_num sig_name/;
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
	return $ret->handler ne 'DEFAULT' ? $ret->handler : undef;
}

sub FETCH {
	my ($self, $key) = @_;
	return $self->_get_status(sig_num($key));
}

sub STORE {
	my ($self, $key, $value) = @_;
	sigaction(sig_num($key), POSIX::SigAction->new($value, $Mask, $Flags));
	return $value;
}

sub DELETE {
	my ($self, $key) = @_;
	return $self->STORE($key, "DEFAULT");
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

=for Pod::Coverage
SCALAR
=cut
