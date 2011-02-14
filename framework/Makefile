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

FW_ROOT         = $(shell pwd)
FRAMEWORK_LOCAL = $(FW_ROOT)/local
JAVASCRIPT_ROOT = $(FW_ROOT)/htdocs/javascript
JAVASCRIPT_LIB  = if.js
PERL_BIN        = $(IF_SANDBOX)/local/bin/perl
BUILD           = $(shell hg log -l1|grep changeset|grep -o  "\([0-9]\+\):"|grep -o "\([0-9]\+\)")
DATE            = $(shell date)

IF_JAVASCRIPT_FILES= \
    StatusMessagesViewer.js \
    ComponentRegistry.js \
    AsynchronousComponent.js \
    Component.js \
    FormComponent.js \
    Form.js \
    Validator.js \
    TextField.js \
    EmailField.js \
    SubmitButton.js \
    KeyValueChooser.js \
    PopUpMenu.js \
    CheckBox.js \
    CheckBoxGroup.js \
    RadioButtonGroup.js \
    ScrollingList.js \
    ClientSideConditional.js \
    TimeDifference.js \
    Span.js
    
PERL_MODULES= \
    DBD-SQLite-1.25 \
    Apache-Reload-0.10

all: perlmods

clean:
    rm -rf build/*
    rm -rf local/*

perlmods:
    echo $(FW_ROOT)
    -for d in $(PERL_MODULES); do (cd build ; tar xvfz $(FW_ROOT)/dependencies/perl/$$d.tar.gz ; cd $$d ; $(PERL_BIN) Makefile.PL PREFIX=$(FRAMEWORK_LOCAL); make; make test; make install ); done

javascript:
    @echo "// IF Javascript lib, build $(BUILD)" > $(JAVASCRIPT_ROOT)/$(JAVASCRIPT_LIB)
    @echo "// Built $(DATE)" >> $(JAVASCRIPT_ROOT)/$(JAVASCRIPT_LIB)
    @cat $(JAVASCRIPT_ROOT)/jquery/plugins/jquery.if.js >> $(JAVASCRIPT_ROOT)/$(JAVASCRIPT_LIB)
    @for d in $(IF_JAVASCRIPT_FILES); do ( cat $(JAVASCRIPT_ROOT)/IF/$$d >> $(JAVASCRIPT_ROOT)/$(JAVASCRIPT_LIB); ); done
    @echo "$(BUILD)" > $(FW_ROOT)/conf/BUILD_VERSION.conf
