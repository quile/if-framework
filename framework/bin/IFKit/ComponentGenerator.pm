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

package IFKit::ComponentGenerator;

use strict;
#=================================
use IF::Model;
use IF::Entity;
use IF::EntityClassDescription;
use IF::Component;
#=================================
use HTML::Template;
use File::Basename;
use File::Path;

sub new {
    my $className = shift;
    my $self = {
            sourceTemplateDirectory => shift,
            componentDirectory => shift,
            templateDirectory => shift,
            bindingDirectory => shift,
    };
    return bless $self, $className;
}

sub createComponentWithNameInNamespace {
    my $self = shift;
    my $component = shift;
    my $tree = shift;

    return $self->createComponentOfTypeWithNameInNamespaceForEntityNamed (
                                    "Component",
                                    $component,
                                    $tree,
                                    "");
}

sub createComponentOfTypeWithNameInNamespaceForEntityNamed {
    my $self = shift;
    my $type = shift;
    my $component = shift;
    my $tree = shift;
    my $entityName = shift;

    my $template = HTML::Template->new(
                    filename => $self->{sourceTemplateDirectory}."/$type.pm",
                    die_on_bad_params => 0,
                    global_vars => 1);

    # populate the attributes  and relationships arrays
    # if we have an entity to work from
    if ($entityName) {
        my $entityClassDescription = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($entityName);

        if ($entityClassDescription) {
            $self->populateTemplateWithEntityClassDescription(
                        $template, $entityClassDescription);
        }
    }


    my $componentPackagePath = $tree.'::'.$component;
    $componentPackagePath =~ s/\//::/g;

    $template->param(ID_TAG => "\$Id\$");
    $template->param(TREE => $tree);
    $template->param(COMPONENT => $componentPackagePath);
    return $template;
}

sub createTemplateWithNameInNamespace {
    my $self = shift;
    my $component = shift;
    my $tree = shift;

    return $self->createTemplateOfTypeWithNameInNamespaceForEntityNamed (
                                    "Component",
                                    $component,
                                    $tree,
                                    "");
}

sub createTemplateOfTypeWithNameInNamespaceForEntityNamed {
    my $self = shift;
    my $type = shift;
    my $component = shift;
    my $tree = shift;
    my $entityName = shift;

    my $template = HTML::Template->new(
                    filename => $self->{sourceTemplateDirectory}."/$type.html",
                    die_on_bad_params => 0,
                    global_vars => 1);

    # populate the attributes  and relationships arrays
    # if we have an entity to work from
    if ($entityName) {
        my $entityClassDescription = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($entityName);

        if ($entityClassDescription) {
            $self->populateTemplateWithEntityClassDescription(
                        $template, $entityClassDescription);
        }
    }

    my $componentPackagePath = $tree.'::'.$component;
    $componentPackagePath =~ s/\//::/g;

    $template->param(ID_TAG => "\$Id\$");
    $template->param(TREE => $tree);
    $template->param(COMPONENT => $componentPackagePath);
    # fill in escaped fields
    $template->param(TMPL_VAR => "TMPL_VAR");
    $template->param(TMPL_IF => "TMPL_IF");
    $template->param(TMPL_LOOP => "TMPL_LOOP");
    $template->param(TMPL_INCLUDE => "TMPL_INCLUDE");
    $template->param(TMPL_UNLESS => "TMPL_UNLESS");
    $template->param(TMPL_ELSE => "TMPL_ELSE");
    return $template;
}

sub createBindingWithNameInNamespace {
    my $self = shift;
    my $component = shift;
    my $tree = shift;

    return $self->createBindingOfTypeWithNameInNamespaceForEntityNamed (
                                    "Component",
                                    $component,
                                    $tree,
                                    "");
}

sub createBindingOfTypeWithNameInNamespaceForEntityNamed {
    my $self = shift;
    my $type = shift;
    my $component = shift;
    my $tree = shift;
    my $entityName = shift;

    my $template = HTML::Template->new(
                    filename => $self->{sourceTemplateDirectory}."/$type.bind",
                    die_on_bad_params => 0,
                    global_vars => 1);

    # populate the attributes  and relationships arrays
    # if we have an entity to work from
    if ($entityName) {
        my $entityClassDescription = IF::Model->defaultModel()->entityClassDescriptionForEntityNamed($entityName);

        if ($entityClassDescription) {
            $self->populateTemplateWithEntityClassDescription(
                        $template, $entityClassDescription);
        }
    }

    my $componentPackagePath = $tree.'::'.$component;
    $componentPackagePath =~ s/\//::/g;

    $template->param(ID_TAG => "\$Id\$");
    $template->param(TREE => $tree);
    $template->param(COMPONENT => $componentPackagePath);
    return $template;
}

sub populateTemplateWithEntityClassDescription {
    my $self = shift;
    my $template = shift;
    my $entityClassDescription = shift;

    return unless $template && $entityClassDescription;

    my $attributes = [];
    foreach my $attribute (values %{$entityClassDescription->attributes()}) {
        if ($attribute->{COLUMN_NAME} eq $entityClassDescription->{PRIMARY_KEY} ||
            $attribute->{COLUMN_NAME} eq "CREATION_DATE" ||
            $attribute->{COLUMN_NAME} eq "MODIFICATION_DATE") {
            $attribute->{IS_SYSTEM_ATTRIBUTE} = 1;
        }

        $self->setBooleanConditionForAttributeType($attribute);
        push (@$attributes, $attribute);
    }

    my $relationships = [];
    foreach my $relationshipName (keys %{$entityClassDescription->relationships()}) {
        my $relationship = $entityClassDescription->relationshipWithName($relationshipName);

        $relationship->{NAME} = $relationshipName;
        push (@$relationships, $relationship);
    }

    $template->param(ATTRIBUTES => $attributes);
    $template->param(RELATIONSHIPS => $relationships);
    $template->param(ENTITY => $entityClassDescription->name());
    $template->param(UPPER_CASE_ENTITY => uc($entityClassDescription->valueForKey("TABLE")));
    $template->param(METHOD_NAME_ENTITY => lcfirst($entityClassDescription->name()));
    $template->param(UPPER_CASE_FIRST_METHOD_NAME_ENTITY => ucfirst($entityClassDescription->name()));
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

sub setBooleanConditionForAttributeType {
    my $self = shift;
    my $attribute = shift;

    if ($attribute->{TYPE} =~ /^int$/i && $attribute->{COLUMN_NAME} =~ /DATE$/) {
        $attribute->{IS_TYPE_UNIX_DATE} = 1;
        return;
    }

    if ($attribute->{TYPE} =~ /int$/i) {
        $attribute->{IS_TYPE_INT} = 1;
        return;
    }

    $attribute->{"IS_TYPE_".uc($attribute->{TYPE})} = 1;
    return;
}

1;
