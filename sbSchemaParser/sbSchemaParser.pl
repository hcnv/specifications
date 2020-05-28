#!/usr/bin/perl

use Cwd qw(abs_path realpath);
use File::Path qw(make_path);
use File::Spec::Functions qw(catdir catfile splitdir);
use JSON::XS;
use YAML::XS qw(LoadFile DumpFile);
use Data::Dumper;
use POSIX qw/strftime/;

$Data::Dumper::Sortkeys =   1;
$YAML::XS::QuoteNumericStrings	=		0;

binmode STDOUT, ":utf8";
my @here_path   =   splitdir(abs_path($0));
pop @here_path;
my $here_path   =   catdir(@here_path);
my $config      =   LoadFile(catfile($here_path, 'config.yaml')) or die "¡No config.yaml file in this path!";
bless $config;

=podmd

The `sbSchemaParser.pl` Perl script parses YAML schema definitions 
written in [_JSON Schema_](https://json-schema.org) which use the standard GA4GH 
[SchemaBlocks {S}[B]](http://schemablocks.org) structure, into 

* JSON versions of the schemas (unprocessed), to serve as the reference
schema versions
* Markdown documentation, both in plain Markdown and as sources for "Jekyll" 
based Markdown => HTML generation by Github Pages (or a local installation)
* example `.json` data files, from the inline `examples`

The output files are generated relative to the script path. This assumes a
directory structure, in which the different repositories are contained in the
same root (i.e. organization) directory, and the script itself is inside a
first order directory in one of the repositories. The specific names of all of 
the directories can be modified in `config.yaml`:

```
this-organization
  |
  |-- tools
  |     |
  |     |-- sbSchemaParser
  |     |     |
  |           |-- sbSchemaParser.pl # this file
  |           |-- config.yaml       # in- and output path definitions
  |
  |-- sb-external-schemas-name      # example for (1 or 1+) schema repositories
  |     |
  |     |-- source
  |     |     |
  |     |     |-- v1.0.1						# versioned representation of the donor code
  |     |
  |     |-- schemas
  |     |     |
  |     |     |-- Schema.yaml
  |     |     |-- OtherSchema.yaml
  |     |     |-- ...
  |     |
  |     |-- working
  |     |     |-- SomethingNew.yaml     
  |     |     |-- ...
  |     |     
  |     |-- generated               # config.yaml -> "out_dirnames"
  |           |
  |           |-- doc
  |           |     |-- Schema.md
  |           |     |-- OtherSchema.md
  |           |     |-- ...
  |           |
  |           |-- json
  |           |     |    
  |           |     |-- current
  |           |     |     |-- Schema.json
  |           |     |     |-- ...
  |           |     |    
  |           |     |-- v0.0.1
  |           |     |     |-- Schema.json
  |           |     |     |-- ...
  |           |     |    
  |           |     |-- v... 
  |           |
  |           |-- examples
  |   
  |-- (webdocs.repo)                # web repository (Jekyll based)
        |
        |-- (webdocs.jekylldir)
        |     |
        |     |-- Schema.md
        |     |-- ...
        |
        |-- (webdocs.schemadir)
              |
              |     |-- Schema.json
              |     |-- ...
              |    
              |-- v0.0.1
              |     |-- Schema.json
              |     |-- ...
              |    
              |-- v...
```

#### Usage

The `sbSchemaParser.pl` script has to be run in a _local_ version of the 
repository structure. In principle, any relative directory locations should be 
possible if specified in the `config.yaml` defaults file, though a reasonable 
approach is to use a "organization -> projects" structure as above.

The script is executed with

```
perl sbSchemaParser.pl
```

The only current option is to provide a "-filter" argument against the schema 
file names; e.g. `perl sbSchemaParser.pl -filter Age` will only process schemas 
with "Age" in their file name.

=cut

$config->{here_path}    =   $here_path;
$config->{git_root_dir} =   realpath($here_path.'/../..');
my $podmd       =   catfile($config->{git_root_dir}, $config->{podmd});

# command line input
my %args        =   @ARGV;
$args{-filter}  ||= q{};
foreach (keys %args) { $config->{args}->{$_} = $args{$_} }

_process_src($config);

# invoking the self-documentation of this script

if (-f $podmd) {
  `perl $podmd` }
  
exit;

################################################################################
################################################################################
# subs
################################################################################
################################################################################

sub _process_src {

=podmd
#### Processing Schema Source Directories

The script parses through the associated source repositories which are required
to reside inside a unified root (`git_root_dir`). The names of the (one or
several) repositories and their schema file source directories (one or several
per repository) are specified in the `config.yaml` file.

=cut

  my $config    =   shift;

  foreach my $src_repo (keys %{ $config->{schema_repos} }) {
    foreach my $src_dir (@{ $config->{schema_repos}->{$src_repo}->{schema_dirs} }) {
      my $src_path  =   catdir(
                          $config->{git_root_dir},
                          $src_repo,
                          $src_dir
                        );
      opendir DIR, $src_path;
      foreach my $schema (grep{ /ya?ml$/ } readdir(DIR)) {
      
        my $paths = {
          schema_file   =>  $schema,
          schema_path   =>  catfile($src_path, $schema),
          schema_dir    =>  $src_dir,
          schema_repo   =>  $src_repo,
        };
    
        _process_yaml($config, $paths);

      }
      close DIR;

}}}

################################################################################
# main file specific process
################################################################################

sub _process_yaml {

  my $config    =   shift;
  my $paths     =   shift;

  bless $paths;
  if ($config->{args}->{-filter} =~ /.../) {


    if ($paths->{schema_file} !~ /$config->{args}->{-filter}/) {
      return } }

  print "Reading YAML file \"$paths->{schema_path}\"\n";

  my $data      =   LoadFile($paths->{schema_path});

=podmd
The class name is derived from the file's "$id" value, assuming a canonical 
path structure with the class name post-pended with a version:

```
"$id": https://schemablocks.org/schemas/sb-phenopackets/Phenopacket/v0.0.1
```
Processing is skipped if the class name does contain other than word / dot / 
dash characters, or if a filter had been provided and the class name 
does not match.

=cut

  if ($data->{title} !~ /^\w[\w\.\-]+?$/) { return }
  
  $paths->_create_file_paths($config, $data);
  foreach my $outFile (grep{ /outfile_\w*?json/} keys %{ $paths }) {
    _export_outfile($paths->{$outFile});
  }
  
  if ($data->{meta}->{sb_status} !~ /\w/) {
  	print "¡¡¡ No sb_status value in $data->{title} => skipping !!!\n";
    return;
  }

=podmd

The documentation is extracted from the YAML schema file and formatted into
markdown content, producing 

* a plain `.md` file in the output directories of the original repository 
(`out_dirnames.markdown`)
* the YAML header prepended file for the webpage generation

=cut

  my $output    =   {
    md          =>  q{},
    jekyll_head =>  _create_jekyll_header($config, $paths, $data),
  };

  $output->{md} .=  <<END;

<div id="schema-header-title">
  <h2>$data->{title} <span id="schema-header-title-project">[$paths->{project}] <a href="$paths->{github_repo_link}" target="_BLANK">&nearr;</a></span> </h2>
</div>

<table id="schema-header-table">
  <tr>
    <th>{S}[B] Status Level <a href="$config->{links}->{sb_status_levels}">[i]</a></th>
    <td><div id="schema-header-status">$data->{meta}->{sb_status}</div></td>
  </tr>
END

  foreach my $attr (qw(provenance used_by contributors)) {
    if ($data->{meta}->{$attr}) {
      my $label =   $attr;
      
      if ($attr eq 'contributors') {
        $output->{md} .=  "\n\n".$config->{jekyll_excerpt_separator}."\n" }
      
      $label    =~  s/\_/ /g;
      $output->{md} .=  '
  <tr>
    <th>'.ucfirst($label).'</th>
    <td>
      <ul>';
      foreach (@{$data->{meta}->{$attr}}) {
        my $text    =   $_->{description};
=podmd

A rudimentary CURIE to URL expansion is performed for prefixes defined in the
configuration file. An example would be the linking of an ORCID id to its web 
address.

=cut
        my $id  =   _expand_CURIEs($config, $_->{id});
        if ($id =~ /\:\/\/\w/) {
          $text =   '<a href="'.$id.'">'.$text.'</a>' }
        elsif ($id =~ /\w/) {
          $text .=  ' ('.$id.')' }
        $output->{md}   .=  "\n<li>".$text."</li>";
      }
      $output->{md} .=  "
      </ul>
    </td>
  </tr>";
  }}
  $output->{md} .=  <<END;

  <tr>
    <th>Source ($paths->{version})</th>
    <td>
      <ul>
        <li><a href="current/$paths->{class}.json" target="_BLANK">raw source [JSON]</a></li>
        <li><a href="$paths->{github_file_link}" target="_BLANK">Github</a></li>
      </ul>
    </td>
  </tr>
</table>

<div id="schema-attributes-title">
  <h3>Attributes</h3>
</div>

END

  foreach my $attr (grep{ $data->{$_} =~ /\w/ }  qw(type format minimum pattern description)) {
    $output->{md}   .=  "  \n__".ucfirst($attr).":__ $data->{$attr}" }

  if ($data->{type} =~ /object/i) {
    $output->{md}   =   _parse_properties($data, $output->{md}) }

  if (@{ $data->{'examples'} } > 0) {
    $output->{md}   .=  "\n\n### `$data->{title}` Value "._pluralize("Example", $data->{'examples'})."  \n\n";
    foreach (@{ $data->{'examples'} }) {
      $output->{md} .=  "```\n".JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($_)."```\n";
    }
  }

  ##############################################################################
  ##############################################################################


=podmd


=cut

  $paths->{outfile_plain_md}->{content}           =   $output->{md};
  $paths->{outfile_jekyll_current_md}->{content}  =   $output->{jekyll_head}.$output->{md}.$config->{schema_disclaimer}."\n";

  foreach my $outFile (grep{ /outfile_\w+?_md/} keys %{ $paths }) {
   _export_outfile($paths->{$outFile});
  }

}

################################################################################
################################################################################
################################################################################

################################################################################
################################################################################

sub _create_file_paths {

=podmd

Paths for output files are created based on the values (e.g. `out_dirnames` 
provided in the configuration file.

The web files for the Jekyll / GH-pages processing receive a prefix, to ensure 
that auto-generated and normal pages can co-exist. The `permalink` parameter 
provided in the YAML header of the Jekyll file provides a "nice" and stable 
name for the generated HTML page (independent of the original file name).

#### Deparsing of the class "$id"

The class "$id" values are assumed to have a specific structure, where 

* the last component is a version id
* the second-to-last component is the class name
* elements before the class name are ignored in parsing

##### Example

```
"$id": https://schemablocks.org/schemas/sb-beacon/BeaconVariant/v1.0.1
```

=cut

  my $paths     =   shift;
  my $config    =   shift;
  my $data      =   shift;

  my @id_comps  =   split('/', $data->{'$id'}); 
  $paths->{version} =   pop @id_comps;
  $paths->{class}   =   pop @id_comps;
  $paths->{project} =   pop @id_comps;
  
  if (! $data->{examples}) { $data->{examples} = [] }

# print Dumper(@id_comps, $paths->{project}, $paths->{class}, $paths->{version});
# print Dumper($data->{examples});

  my $fileClass =   $paths->{schema_file};
  $fileClass    =~  s/\.\w+?$//;

  _check_class_name($paths->{class}, $fileClass);
  
  $paths->{outfile_exmpls_json}   =   {
    path        =>  catfile(
                      $config->{git_root_dir},
                      $paths->{schema_repo},                      
                      $config->{out_dirnames}->{examples},
                      $paths->{class}.'-examples.json'
                    ),
    content     =>  JSON::XS->new->pretty( 1 )->canonical()->encode( $data->{examples} ),
  };
  $paths->{outfile_plain_md}  =   {
    path        =>  catfile(
                      $config->{git_root_dir},
                      $paths->{schema_repo},
                      $config->{out_dirnames}->{markdown},
                      $paths->{class}.'.md'
                    ),
    content     =>  q{}
  };
  $paths->{outfile_src_json_current}  =   {
    path        =>  catfile(
                      $config->{git_root_dir},
                      $paths->{schema_repo},
                      $config->{out_dirnames}->{json},
                      'current',
                      $paths->{class}.'.json'
                    ),
    content     =>  JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($data),
  };
  $paths->{outfile_src_json_versioned}  =   {
    path        =>  catfile(
                      $config->{git_root_dir},
                      $paths->{schema_repo},
                      $config->{out_dirnames}->{json},
                      $paths->{version},
                      $paths->{class}.'.json'
                    ),
    content     =>  JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($data),
  };
  $paths->{outfile_web_src_json_current}  =   {
    path        =>  catfile(
                      $config->{git_root_dir},
                      $config->{webdocs}->{repo},
                      $config->{webdocs}->{schemadir},
                      $paths->{project},
                      'current',
                      $paths->{class}.'.json'
                    ),
    content     =>  JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($data),
  };
  $paths->{outfile_web_src_json_versioned}  =   {
    path        =>  catfile(
                      $config->{git_root_dir},
                      $config->{webdocs}->{repo},
                      $config->{webdocs}->{schemadir},
                      $paths->{project},
                      $paths->{version},
                      $paths->{class}.'.json'
                    ),
    content     =>  JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($data),
  };
  $paths->{outfile_jekyll_current_md}   =   {
    path        =>  catfile(
                      $config->{git_root_dir},
                      $config->{webdocs}->{repo},
                      $config->{webdocs}->{jekylldir},
                      $paths->{project},
                      $config->{generator_prefix}.$paths->{class}.'.md'
                    ),
    content     =>  q{}
  };
  $paths->{github_repo_link} =   join('/',
    'https://github.com',
    $config->{github_organisation},
    $paths->{schema_repo},
  );
  $paths->{github_file_link} =   join('/',
    'https://github.com',
    $config->{github_organisation},
    $paths->{schema_repo},
    'blob',
    'master',
    $paths->{schema_dir},
    $paths->{schema_file}
  );
  $paths->{web_link_json}   =   join('/',
    $config->{webdocs}->{web_schemas_rel},
    $paths->{project},
    'current',
    $paths->{class}.'.json'
  );
  $paths->{doc_link_html}   =   join('/',
    $config->{webdocs}->{web_html_rel},
    $paths->{project},
    $paths->{class}.'.html'
  );

  return $paths;

}

################################################################################
################################################################################

sub _check_class_name {

  my $sbClass   =   shift;
  my $fileClass =   shift;

  if ($sbClass ne $fileClass) {
    print <<END;
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Mismatch between file name
  $fileClass
and class name from "\$id" parameter
  $sbClass

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
END

  }
}

################################################################################
################################################################################

sub _parse_properties {

  my $data      =   shift;
  my $md        =   shift;

  $md           .=  <<END;

### Properties

<table id="schema-properties-table">
  <tr>
    <th>Property</th>
    <th>Type</th>
  </tr>
END

  foreach my $property ( sort keys %{ $data->{properties} } ) {
    my $label   =   _format_property_type_html($data->{properties}->{$property});
    $md         .=  <<END;
  <tr>
    <th>$property</th>
    <td>$label</td>
  </tr>
END
  }

  $md           .=  "\n".'</table>'."\n\n";

=podmd
The property overview is followed by the listing of the properties, including
descriptions and examples.

=cut

  foreach my $property ( sort keys %{ $data->{properties} } ) {
    my $label   =   _format_property_type_html($data->{properties}->{$property});
    my $description	=		_format_property_description($data->{properties}->{$property});
    $md         .=  <<END;

#### $property

* type: $label

$description

END
	my $propEx	=		_format_property_examples($data->{properties}->{$property});
		if (@$propEx > 0) {
		$md         .=  "##### `$property` Value "._pluralize("Example", $propEx)."  \n\n";
		foreach (@$propEx) {
		  $md       .=  "```\n".$_."```\n";
		}
    }

  }

  return $md;

}

################################################################################
################################################################################

sub _create_jekyll_header {

=podmd

#### Jekyll File Header

A version of the Markdown inline documentation is added to the Github (or 
alternative), Jekyll based website source tree.

The page will only be generated into an HTML page if it contains a specific 
header written in YAML.

The `_create_jekyll_header` function will pre-pend such a header to the Markdown 
page, including some file specific parameters such as the `permalink` address of 
the page.

=cut

  my $config    =   shift;
  my $paths     =   shift;
  my $data      =   shift;
  my @tags		=	grep{ /../ } (@{ $config->{tags} }, $data->{meta}->{sb_status}, $paths->{project});
  my $today		=	strftime("%Y-%m-%d", localtime);
  my $header	=	<<END;
---
title: $paths->{class}
layout: default
date: $today
permalink: "$paths->{doc_link_html}"
sb_status: "$data->{meta}->{sb_status}"
excerpt_separator: $config->{jekyll_excerpt_separator}
category:
  - schemas
tags:
END

	foreach (@tags) {
		$header			.=	"  - ".$_."\n";
	}
	$header				.=	"---\n";

	return $header;

}

################################################################################
################################################################################

sub _format_property_type_html {

  my $prop_data =   shift;
  
=podmd
##### Hacking the "$ref is a solitary attribute" problem

In the current JSON Schema specification there is a problem with "$ref"-type 
attribute types: If a reference is given, additional attributes of the property 
(examples, description) are being ignored. This isn't very helpful, since 
information specific to the property's _instantiation_ will not be displayed.

This behaviour can be alleviated by wrapping the `$ref` and other attributes 
with an `allof` statement (which is interpolated in the following, to expose 
the attributes). We'll hope for a more elegant solution ...

=cut

	$prop_data    =   _remap_allof($prop_data);
		  
  my $typeLab;
  my $type      =   q{};
  if ($prop_data->{type}) {
  	$type				=		$prop_data->{type} }
  if (
  	$type !~ /.../
  	&&
  	$prop_data->{'$ref'} =~ /.../
  ) { $typeLab  =   $prop_data->{'$ref'} }
  elsif ($type =~ /array/) {
  	if ($prop_data->{items}->{'$ref'} =~ /.../) {
    	$typeLab  =   $prop_data->{items}->{'$ref'} }
  	elsif ( ref($prop_data->{items}) !~ /HASH/ ) {
    	$typeLab  =   $prop_data->{items} }
    else {
    	$typeLab  =   $prop_data->{items}->{type} }
  }
  else {
    $typeLab    =   $type;
    if ($prop_data->{"format"} =~ /.../) {
    	$typeLab	.=	' ('.$prop_data->{"format"}.')' }
  }

  if ($typeLab =~ /\/[\w\-]+?(\.\w+?)?$/) {
    my $yaml    =   $typeLab;
    $yaml       =~  s/\.\w+?$//;
    my $html    =   $yaml;
    $html       .=  '.html';
    $html       =~  s/v\d+?\.\d+?\.\d+?\///;
    $typeLab    .=  ' [<a href="'.$html.'" target="_BLANK">HTML</a>]' }

  if ($type =~ /array/) {
    $typeLab    =   'array of "'.$typeLab.'"' }

    return $typeLab;

}


################################################################################
################################################################################

sub _remap_allof {

=podmd
##### Helper `_remap_allof`

This function remaps the list of property attributes required from using a 
'$ref' property definition to a standard object, which is then processed for
documentation in the usual way.

TODO: 
* be aware of the possibility of multiple "$ref" elements (not in the {S}[B]
specifications right now) which would being reduced to one
* hoping for _JSON Schema_ to fix the "$ref" format requirement ...

=cut

  my $prop_data =   shift;
  my $prop      =   {};

	if (ref($prop_data) !~ /HASH/) { return $prop_data }
	if (! $prop_data->{allof}) { return $prop_data }

  foreach my $of (@{ $prop_data->{allof} }) {		  
    if ((keys %$of )[0] eq '$ref') {
      $prop->{'$ref'}  =   $of->{'$ref'} }
    else {
      foreach (sort keys %$of) {
        $prop->{$_}    =   $of->{$_};
      }
    }	  
  }
 
  return $prop;
  
}
 
################################################################################
################################################################################

sub _format_property_description {

=podmd

=cut

  my $prop_data =   shift;
	$prop_data    =   _remap_allof($prop_data);

  return $prop_data->{description};

}

################################################################################
################################################################################

sub _format_property_examples {

=podmd

=cut

  my $prop_data =   shift;
  my $ex_md			=		[];	
	$prop_data    =   _remap_allof($prop_data);
 
	foreach my $example (@{ $prop_data->{'examples'} }) {
		if (grep { $prop_data->{type} =~ /$_/ } qw(num int) ) { $example *= 1 }
		push(@$ex_md, JSON::XS->new->pretty( 1 )->allow_nonref->canonical()->encode($example));
	}

  return $ex_md;

}

################################################################################
################################################################################
=podmd

### Helper Subroutines

=cut
################################################################################
################################################################################

sub _expand_CURIEs {

=podmd
#### `_expand_CURIEs`

This function expands prefixes in identifiers, based on the parameters provided 
in `config.yml`. This is thought as a helper for some script/website specific 
linking, not as a general CURIE expansion utility.

=cut

  my $config    =   shift;
  my $curie     =   shift;

  if (grep{ $curie =~ /^$_\:/ } keys %{ $config->{prefix_expansions} }) {
    my $pre     =   (grep{ $curie =~ /^$_\:/ } keys %{ $config->{prefix_expansions} })[0];
    $curie      =~  s/$pre\:/$config->{prefix_expansions}->{$pre}/;
  }

  return $curie;

}

################################################################################
################################################################################

sub _export_outfile {
  
  my $fileObj   =   shift;

  print "writing $fileObj->{path}\n";
  my $dir     	=   $fileObj->{path};
  $dir        	=~  s/\/[^\/]+?\.\w+?$//;
  if (! -d $dir) {
  	make_path($dir) }
  open  (FILE, ">", $fileObj->{path}) || warn '!!! output file '. $fileObj->{path}.' could not be created !!!';
  print FILE  $fileObj->{content}."\n";
  close FILE;
  
}

################################################################################
################################################################################

sub _pluralize {
  my $word      =   shift;
  my $list      =   shift;
  if (@$list > 1) { $word .= 's' }
  return $word;
}
