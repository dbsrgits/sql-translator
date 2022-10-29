# About

Our website: <https://sqlfairy.sourceforge.net/>

**SQL::Translator** is a group of Perl modules that manipulate structured data definitions (mostly database schemas) in interesting ways, such as:
- converting among different dialects of CREATE syntax (e.g., MySQL-to-Oracle), 
- visualizations of schemas (pseudo-ER diagrams: [GraphViz](http://www.graphviz.org/) or GD), 
- automatic code generation (using [Class::DBI](https://metacpan.org/dist/Class-DBI)), 
- converting non-RDBMS files to SQL schemas (xSV text files, Excel spreadsheets), 
- serializing parsed schemas (via Storable, [YAML](https://yaml.org/) and XML), 
- creating documentation (HTML and POD), 
- and more. 

New to version 0.03 is the ability to talk directly to a database through [DBI](https://metacpan.org/dist/DBI) to query for the structures of several databases.

Through the separation of the code into parsers and producers with an object model in between, it's possible to combine any parser with any producer, to plug in custom parsers or producers, or to manipulate the parsed data via the built-in object model. Presently only the definition parts of SQL are handled (`CREATE`, `ALTER`), not the manipulation of data (`INSERT`, `UPDATE`, `DELETE`).

# Join Us

If you would like to contribute to the project, you can send patches to the developers mailing list at <sqlfairy-developers@lists.sourceforge.net>, or send a message to one of the project admins ([dlc](https://sourceforge.net/users/dlc/), [kycl4rk](https://sourceforge.net/users/kycl4rk/), or [mwz444](https://sourceforge.net/users/mwz444/)) asking to be added to the project and what you'd like to contribute. Be sure to include your SourceForge username.

# Copyright

**SQL::Translator** is free software; you can redistribute it and/or modify it under [the same terms as Perl itself](http://dev.perl.org/licenses/).

![Logo](http://sqlfairy.sourceforge.net/images/logo.jpg)
