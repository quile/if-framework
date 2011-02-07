package IF::Interface::Privilege;
use strict;
use IF::Log;
use Math::BigInt ();

sub hasPrivilegeTo {
	my $self = shift;
	my $action = shift;
	return $self->hasPrivilege($self->privilegeWithName($action));
}

sub hasPrivilege {
	my $self = shift;
	my $action = shift;
	my $privilegeAsBigInt = Math::BigInt->new($self->bigIntFromHex($self->privilege()));
	my $actionAsBigInt = Math::BigInt->new($self->bigIntFromHex($action));
	return ($privilegeAsBigInt->band($actionAsBigInt) == $actionAsBigInt);
}

sub privilegeWithName {
	my $self = shift;
	my $action = shift;

	my $className = ref $self;
	no strict 'refs';
	my $privileges = ${$className."::PRIVILEGES"};
	my $privilegeWithName = $privileges->{$action};
	unless ($privilegeWithName) {
		IF::Log::warning("Attempt to use non-existent privilege $action on class $className");
		return 0;
	}
	return $privilegeWithName;
}

sub grantPrivilegeTo {
	my $self = shift;
	my $privilege = shift;
	return $self->grantPrivilege($self->privilegeWithName($privilege));
}

sub revokePrivilegeTo {
	my $self = shift;
	my $privilege = shift;
	return $self->revokePrivilege($self->privilegeWithName($privilege));
}

sub grantPrivilege {
	my $self = shift;
	my $action = shift;
	my $privilegeAsBigInt = Math::BigInt->new($self->bigIntFromHex($self->privilege()));
	my $actionAsBigInt = Math::BigInt->new($self->bigIntFromHex($action));
	my $newPrivilege = Math::BigInt->new($privilegeAsBigInt->bior($actionAsBigInt));
	$self->setPrivilege($self->hexFromBigInt($newPrivilege));
}

sub revokePrivilege {
	my $self = shift;
	my $action = shift;
	my $privilegeAsBigInt = Math::BigInt->new($self->bigIntFromHex($self->privilege()));
	my $actionAsBigInt = Math::BigInt->new($self->bigIntFromHex($action));
#IF::Log::debug("Privilege is $privilegeAsBigInt, action is $actionAsBigInt");
	my $bitMask = $self->bigIntFromHex("ffffffffffffffff");
	$bitMask = $bitMask->bxor($actionAsBigInt);
#IF::Log::debug("Bitmask is $bitMask");
	my $newPrivilege = Math::BigInt->new($privilegeAsBigInt->band($bitMask));
#IF::Log::debug("Privilege NOT action = $newPrivilege");
	if ($self->can("setStoredValueForKey")) {
		$self->setStoredValueForKey($self->hexFromBigInt($newPrivilege), "privilege");
	} else {
		$self->{PRIVILEGE} = $self->hexFromBigInt($newPrivilege);
	}
}

sub privilege {
	my $self = shift;
	my $privilege;
	if ($self->can("storedValueForKey")) {
		$privilege = $self->storedValueForKey("privilege");
	} else {
		$privilege = $self->{PRIVILEGE};
	}
	return $privilege || "0000000000000000";
}

# Roles are just combinations of privileges,
# nothing special.  For example, an ADMINISTRATOR
# has all privileges, a VMS_MANAGER might have
# a subset of privileges, etc.

sub hasRole {
	my $self = shift;
	my $role = shift;

	my $className = ref $self;
	no strict 'refs';
	my $roles = ${$className."::ROLES"};
	my $roleWithName = $roles->{$role};
#IF::Log::debug("Administrator role is $roleWithName");
	return $self->hasPrivilege($roleWithName);
}

#=====================================================
# manipulates privileges
#=====================================================

sub bigIntFromHex {
	my $self = shift;
	my $string = shift;

	return unless $string;
	return unless length($string) == 16;
	my $bigInt = Math::BigInt->new();
	my $lowOrderWord = substr($string, -8);
	my $highOrderWord = substr($string, 0, 8);

	my $lowOrderBigInt = Math::BigInt->new(hex($lowOrderWord));
	my $highOrderBigInt = Math::BigInt->new(hex($highOrderWord));

	my $result = $highOrderBigInt->blsft(Math::BigInt->new("32")) + $lowOrderBigInt;
#IF::Log::debug("Low order is $lowOrderBigInt, high is $highOrderBigInt, result is $result");
	return $result;
}

sub hexFromBigInt {
	my $self = shift;
	my $bigInt = shift;
	return "0000000000000000" unless $bigInt;
	return "0000000000000000" if $bigInt eq "NaN";
	my $thirtyTwoBits = "4294967296";  # ouch
	my ($highOrderBigInt, $lowOrderBigInt) = $bigInt->bdiv(Math::BigInt->new($thirtyTwoBits));
#IF::Log::debug("Low order is $lowOrderBigInt, high is $highOrderBigInt, original is $bigInt");
	my $hex = sprintf("%08x%08x", "$highOrderBigInt", "$lowOrderBigInt");
#IF::Log::debug("Hex is $hex");
	return $hex;
}

1;
