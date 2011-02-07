IF Framework
============

This is the framework that evolved over the course of 8+ years
and was in constant deployed use at AWB.

It is highly influenced by Apple's WebObjects and EOF, and comprises
a component-based rendering system, i18n features, skinning,
persistent sessions, and an ORM (currently with SQLite and MySQL
backends).

It's written in Perl, but it makes use of the same kind of
naming idioms (and some design patterns and idioms) as most 
of the Apple Cocoa/Foundation code, so it may seem a bit weird 
at first.  It also avoids many magical things about 
Perl, preferring instead to rely on
more explicit means to get things done.  This may seem very
un-perlish to a lot of seasoned Perl developers.

This is the initial commit, so it's extremely rough; remember
that it was not exactly written to be generic, so there will be 
a bit of work involved to get it to be super user-friendly.
Even though it had been running for years in a high-traffic
deployment, it was bound to that deployment fairly tightly, so decoupling
it has been interesting.

There is a port of this to Objective-J under way at 
[Womble](http://github.com/quile/Womble)

-kd
