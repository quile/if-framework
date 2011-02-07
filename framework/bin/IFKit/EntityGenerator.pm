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

package IFKit::EntityGenerator;

use strict;
use File::Basename;
use File::Path;
#============================================
use IF::Model;
use IF::EntityClassDescription;
use IF::Entity;
use HTML::Template;
#============================================

sub new {
	my $className = shift;
	my $self = {
			sourceTemplateDirectory => shift,
		};
	return bless $self, $className;
}

sub stringInClassNameFormat {
	my $string = shift;
	return join("", map {ucfirst(lc($_))} split(/[_ ]/, $string));
}

sub stringInMethodNameFormat {
	my $string = shift;
	return lcfirst(join("", map {ucfirst(lc($_))} split(/[_ ]/, $string)));
}

# TODO: This should load in an existing class file
# and parse it out into the stuff that is generated
# versus the stuff that's not.
# tricky...

sub parseExistingEntityClass {
	my $self = shift;
	my $classFile = shift;

	return {};
}

sub addAccessorsToEntityClassWithSourceFromStubAndModel {
	my $self = shift;
	my $entityName = shift;
	my $entitySource = shift;
	my $stubEntity = shift;
	my $model = shift;

	my $entityClassDescription = $model->entityClassDescriptionForEntityNamed($entityName);
	#IF::Log::debug("Generating accessors for class $entityName");
	my $accessors = [];
	my $existingGetters = [];
	my $strangeGetters = [];
	my $existingSetters = [];
	my $strangeSetters = [];

	foreach my $attribute (keys %{$entityClassDescription->attributes()}) {
		next if $attribute eq $entityClassDescription->valueForKey("PRIMARY_KEY");
		#next if  $attribute eq "CREATION_DATE";
		next if  $attribute eq "MODIFICATION_DATE";
		my $defaultValueForAttribute = $entityClassDescription->defaultValueForAttribute($attribute);

		#if (defined($defaultValueForAttribute)) {
		#	push (@$initialisations, { KEY => $attribute });
		#	} else {
		#	IF::Log::debug("Default value for $attribute is ". $defaultValueForAttribute);
		#}
		my $getMethodName = stringInMethodNameFormat($attribute);
		my $setMethodName = stringInMethodNameFormat("SET_".$attribute);
		my $accessorRecord = { KEY => $attribute, ATTRIBUTE_NAME => $getMethodName };

		if ($stubEntity->can($getMethodName)) {
			#IF::Log::debug("--> get method is present for $attribute");
			push (@$existingGetters, { %$accessorRecord,
										GETTER => $getMethodName,
									});
		} else {
			$accessorRecord->{GETTER} = $getMethodName;
			#IF::Log::debug("--> generating get method for $attribute");
		}

		if ($stubEntity->can($setMethodName)) {
			#IF::Log::debug("--> set method is present for $attribute");
			push (@$existingSetters, { %$accessorRecord,
										SETTER => $setMethodName,
									});
		} else {
			$accessorRecord->{SETTER} = $setMethodName;
			#IF::Log::debug("--> generating set method for $attribute");
		}
		push (@$accessors, $accessorRecord);
	}

	# start with the accessors:

	my $newSource = "";

	foreach my $accessor (@$accessors) {
		if ($accessor->{GETTER}) {
			$newSource .= <<EOG;
sub $accessor->{GETTER} {
	my \$self = shift;
	return \$self->storedValueForKey("$accessor->{ATTRIBUTE_NAME}");
}

EOG
		}

		if ($accessor->{SETTER}) {
			$newSource .= <<EOS;
sub $accessor->{SETTER} {
	my \$self = shift;
	my \$value = shift;
	\$self->setStoredValueForKey(\$value, "$accessor->{ATTRIBUTE_NAME}");
}

EOS
		}
	}

	#IF::Log::debug("Generated some additional source: \n$newSource");

	# Now check for existing methods
	foreach my $getter (@$existingGetters) {
		local $1;
		$entitySource =~ /(sub $getter->{GETTER} \{.*?^\})/ms;
		my $getterSource = $1;
		#IF::Log::debug($getterSource);
		unless (length($getterSource) > 0) {
			$getter->{INHERITED} = 1;
		}
		my $originalSource = $getterSource;
		#IF::Log::debug("Found existing getter $getterSource");
		# we need to fix this getter
		if (getterMethodIsCorrectFormat($getterSource)) {
			$getterSource =~ s/return \$self->\{$getter->{KEY}\};/return \$self->storedValueForKey\("$getter->{ATTRIBUTE_NAME}"\);/g;
			#IF::Log::debug("Replacing with $getterSource");
			$entitySource =~ s/sub $getter->{GETTER} \{.*?^\}/$getterSource/ms;
		} else {
			push (@$strangeGetters, $getter);
			#IF::Log::debug("Found strange getter for $getter->{GETTER}");
			$entitySource =~ s/sub $getter->{GETTER} \{/\# TODO: Fix this noncorming getter:\nsub $getter->{GETTER} \{/ms;
		}
	}

	# Now check for existing methods
	foreach my $setter (@$existingSetters) {
		local $1;
		$entitySource =~ /(sub $setter->{SETTER} \{.*?^\})/ms;
		my $setterSource = $1;
		unless (length($setterSource) > 1) {
			$setter->{INHERITED} = 1;
		}
		my $originalSource = $setterSource;
		#IF::Log::debug("Found existing setter $setterSource");
		# we need to fix this setter
		if (setterMethodIsCorrectFormat($setterSource)) {
			$setterSource =~ s/\$self->\{$setter->{KEY}\}\s*=\s*shift;/my \$value = shift;\n\t\$self->setStoredValueForKey\(\$value, "$setter->{ATTRIBUTE_NAME}"\);/g;
			#IF::Log::debug("Replacing with $setterSource");
			$entitySource =~ s/sub $setter->{SETTER} \{.*?^\}/$setterSource/ms;
		} else {
			push (@$strangeSetters, $setter);
			#IF::Log::debug("Found strange setter for $setter->{SETTER}");
			$entitySource =~ s/sub $setter->{SETTER} \{/\# TODO: Fix this noncorming setter:\nsub $setter->{SETTER} \{/ms;
		}
	}

	# insert new methods:

	if (length($newSource) > 0) {
		$newSource = "# Generated methods start here\n\n".$newSource."\n# Generated methods end here\n\n";
	}
	$entitySource =~ s/^1;$/$newSource\n\n1;/sm;

	#IF::Log::debug("Final entity source:\n$entitySource");

	if (scalar @$strangeGetters) {
		print "Getter methods that need to be checked:\n";
		foreach my $strangeGetter (@$strangeGetters) {
			print $entityName."::".$strangeGetter->{GETTER}.($strangeGetter->{INHERITED}?" (Inherited)\n" : "\n");
		}
		print "\n";
	}
	if (scalar @$strangeSetters) {
		print "Setter methods that need to be checked:\n";
		foreach my $strangeSetter (@$strangeSetters) {
			print $entityName."::".$strangeSetter->{SETTER}.($strangeSetter->{INHERITED}?" (Inherited)\n" : "\n");
		}
		print "\n";
	}
	return $entitySource;
}

sub generateEntityClassFromRepresentationAndModel {
	my $self = shift;
	my $entityName = shift;
	my $entityRepresentation = shift;
	my $model = shift;

	my $template = HTML::Template->new(
						filename => $self->{sourceTemplateDirectory}."/Entity.pm",
						die_on_bad_params => 0);

	my $entityClassDescription = $model->entityClassDescriptionForEntityNamed($entityName);

	my $initialisations = [];
	my $relationships = [];
	my $accessors = [];

	foreach my $attribute (keys %{$entityClassDescription->attributes()}) {
		next if $attribute eq $entityClassDescription->valueForKey("PRIMARY_KEY");
		next if  $attribute eq "CREATION_DATE";
		next if  $attribute eq "MODIFICATION_DATE";
		my $defaultValueForAttribute = $entityClassDescription->defaultValueForAttribute($attribute);

		if (defined($defaultValueForAttribute)) {
			push (@$initialisations, { KEY => $attribute });
		} else {
			IF::Log::debug("Default value for $attribute is ". $defaultValueForAttribute);
		}
		push (@$accessors, { KEY => $attribute,
							 GETTER => stringInMethodNameFormat($attribute),
							 SETTER => stringInMethodNameFormat("SET_".$attribute),
							 ATTRIBUTE_NAME => stringInMethodNameFormat($attribute),
						  });
	}

	foreach my $relationshipName (keys %{$entityClassDescription->relationships()}) {
		my $relationship = $entityClassDescription->relationships()->{$relationshipName};

		push (@$relationships, { RELATIONSHIP => $relationshipName,
								 RELATIONSHIP_SETTER => "set".ucfirst($relationshipName),
								 RELATIONSHIP_ADDER => stringInMethodNameFormat("ADD_OBJECT_TO").ucfirst($relationshipName),
								 RELATIONSHIP_REMOVER => stringInMethodNameFormat("REMOVE_OBJECT_FROM").ucfirst($relationshipName),
								 RELATIONSHIP_IS_TO_ONE => ($relationship->{TYPE} eq "TO_ONE")? 1:0,
							 });
	};

	$template->param(ACCESSORS => $accessors);
	$template->param(INITIALISATIONS => $initialisations);
	$template->param(RELATIONSHIPS => $relationships);
	$template->param(HAS_RELATIONSHIPS => scalar @$relationships > 0);

	return $template;
}

sub generateStubEntityClassFromRepresentationAndModel {
	my $self = shift;
	my $entityName = shift;
	my $entityRepresentation = shift;
	my $model = shift;

	my $template = HTML::Template->new(
						filename => $self->{sourceTemplateDirectory}."/StubEntity.pm",
						die_on_bad_params => 0);
	return $template;
}

sub saveTemplateToFile {
	my $self = shift;
	my $template = shift;
	my $fileName = shift;

	makeSurePathExistsForFile($fileName);
	open (FILE, ">$fileName") || die "Couldn't write to file $fileName";
	print FILE $template->output();
	close (FILE);
}

#TODO: no error handling here...
sub makeSurePathExistsForFile {
	my $file = shift;
	my $path = dirname($file);
	my @dirs = mkpath([$path]);
}

sub getterMethodIsCorrectFormat {
	my $source = shift;
	$source =~ s/^\s\#.*$//g;
	return 0 unless ($source =~ /(^\s*sub [A-Za-z0-9_]* \{\s*$)/sm);
	$source =~ s/$1//g;
	return 0 unless ($source =~ /(^\s*my \$self\s*=\s*shift;\s*$)/sm);
	$source =~ s/$1//g;
	return 0 unless ($source =~ /(^\s*return \$self->\{[A-Za-z0-9_]+\};\s*$)/sm);
	return 1;
}

sub setterMethodIsCorrectFormat {
	my $source = shift;
	$source =~ s/^\s\#.*$//g;
	return 0 unless ($source =~ /(^\s*sub [A-Za-z0-9_]* \{\s*$)/sm);
	$source =~ s/$1//g;
	return 0 unless ($source =~ /(^\s*my \$self\s*=\s*shift;\s*$)/sm);
	$source =~ s/$1//g;
	return 0 unless ($source =~ /(^\s*\$self->\{[A-Za-z0-9_]+\}\s*=\s*shift;\s*$)/sm);
	return 1;
}

1;