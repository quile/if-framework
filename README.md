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



INSTALL
-------
I'll write a proper install document soon.  For now, it
really helps to check out

[if-sandbox](http://github.com/quile/if-sandbox)

and build that, set up your IF_SANDBOX environment
variable, and then check out this project.  I will
be posting sample applications that use the framework
shortly.



ROUGH EDGES
-----------

Ironically, the oldest and most commonly used parts of the system are also
the roughest, because they were developed first -- often in the absence of
a lot of the tools and features that grew up around them.  The system
web components, in framework/lib/IF/Component, are very bad examples
of how to build components, for this very reason.  I have refactored some of
the core parts of the system, but there is still a lot of pointy bits
that will hurt you if you poke around too much!



-kd
