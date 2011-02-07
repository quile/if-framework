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

package IF::Classes;

# System core classes:
use IF::Config;
use IF::Application;
use IF::Cache;
use IF::CachedObjectManager;
use IF::CacheEntry;
use IF::Log;
use IF::LogMessage;

# Data-source related classes:
use IF::DB;
use IF::FetchSpecification;
use IF::SummarySpecification;
use IF::StoredResult;
use IF::Qualifier;
use IF::SQLExpression;
use IF::Relationship::Modelled;
use IF::Relationship::Derived;
use IF::Relationship::Dynamic;
use IF::Relationship::ManyToMany;
use IF::Query;

# Data model classes:
use IF::EntityClassDescription;
use IF::Entity;
use IF::Entity::Persistent;
use IF::Entity::Transient;
use IF::PrimaryKey;
use IF::Entity::UniqueIdentifier;
use IF::AggregateEntity;
use IF::_AggregatedKeyValuePair;
use IF::Model;
use IF::ObjectContext;

# Rendering classes:
use IF::Component;
use IF::CachingComponent;
use IF::AsynchronousComponent;
use IF::Components;
use IF::Template;
use IF::Response;
use IF::PageResource;

# Classes pertaining to client-server-state
use IF::Context;
use IF::Session;
use IF::RequestContext;
use IF::SiteClassifier;

# Useful classes:
use IF::Utility;
use IF::Web::ActionLocator;
use IF::GregorianDate;
use IF::File;
use IF::File::Image;
use IF::Timer;
use IF::Mailer;

# collection classes
use IF::Array;
use IF::Dictionary;

# I18N
use IF::I18N;

1;
