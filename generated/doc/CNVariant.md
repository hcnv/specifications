
<div id="schema-header-title">
  <h2>CNVariant <span id="schema-header-title-project">[specifications] <a href="https://github.com/hcnv/specifications" target="_BLANK">&nearr;</a></span> </h2>
</div>

<table id="schema-header-table">
  <tr>
    <th>{S}[B] Status Level <a href="https://schemablocks.org/about/sb-status-levels.html">[i]</a></th>
    <td><div id="schema-header-status">playground</div></td>
  </tr>

  <tr>
    <th>Provenance</th>
    <td>
      <ul>
<li><a href="https://hcnv.github.io/schemas/specifications/">hCNV community project</a></li>
      </ul>
    </td>
  </tr>
  <tr>
    <th>Used by</th>
    <td>
      <ul>
<li>ELIXIR hCNV community</li>
      </ul>
    </td>
  </tr>

<!--more-->

  <tr>
    <th>Contributors</th>
    <td>
      <ul>
<li><a href="https://hcnv.github.io/categories/people.html">ELIXIR hCNV team</a></li>
<li><a href="https://orcid.org/0000-0002-9903-4248">Michael Baudis</a></li>
      </ul>
    </td>
  </tr>
  <tr>
    <th>Source (0.0.1-draft.1)</th>
    <td>
      <ul>
        <li><a href="current/CNVariant.json" target="_BLANK">raw source [JSON]</a></li>
        <li><a href="https://github.com/hcnv/specifications/blob/master/schemas/CNVariant.yaml" target="_BLANK">Github</a></li>
      </ul>
    </td>
  </tr>
</table>

<div id="schema-attributes-title">
  <h3>Attributes</h3>
</div>

  
__Type:__ object  
__Description:__ The document describes a draft variant schema, for modeling CN variant objects.

### Properties

<table id="schema-properties-table">
  <tr>
    <th>Property</th>
    <th>Type</th>
  </tr>
  <tr>
    <th>basePloidy</th>
    <td>integer</td>
  </tr>
  <tr>
    <th>digest</th>
    <td>string</td>
  </tr>
  <tr>
    <th>featureAnnotations</th>
    <td>array of "object"</td>
  </tr>
  <tr>
    <th>id</th>
    <td>string</td>
  </tr>
  <tr>
    <th>info</th>
    <td>object</td>
  </tr>
  <tr>
    <th>referenceGenome</th>
    <td>string</td>
  </tr>
  <tr>
    <th>referenceId</th>
    <td>string</td>
  </tr>
  <tr>
    <th>svarEnd</th>
    <td></td>
  </tr>
  <tr>
    <th>svarStart</th>
    <td>https://github.com/ga4gh/vr-spec/blob/116-patch-future-plans/schema/vr.json#118</td>
  </tr>
  <tr>
    <th>variantType</th>
    <td>object</td>
  </tr>

</table>


#### basePloidy

* type: integer

base ploidy of the genomic reference


#### digest

* type: string

* Concatenated unique specific elements of the variant.
* Optional, convenience element to derive unique variants in "individual
variant from callset" storage systems
* Possible use of e.g. HGVS-style annotations, but _not_ defined as such


##### `digest` Value Example  

```
"4:12282-46465:DEL"
```

#### featureAnnotations

* type: array of "object"




#### id

* type: string

* local-unique identifier of this variant (referenced as "variant_id")
* Optional


##### `id` Value Example  

```
"amvar-8754-7751-1119-8539"
```

#### info

* type: object

miscellaneous key-value pairs (where values can be objects)



#### referenceGenome

* type: string

GRC reference genome edition

##### `referenceGenome` Value Example  

```
"GRCh38"
```

#### referenceId

* type: string

* Identifier for a reference sequence, generally describing a chromosome.
* The use of standard sequence identifiers with version (e.g. `NC_000009.12`)
obviates the separate need for a `referenceGenome` parameter'
* TODO: Stricter definition of identifier use


##### `referenceId` Value Examples  

```
"NC_000009"
```
```
"NC_000006.12"
```

#### svarEnd

* type: 

- Information about range in which the end of the CNV has been mapped. This
  corresponds to the GA4GH GKS VRS "SimpleInterval". Also see annotation for `svarStart`.


##### `svarEnd` Value Example  

```
{
   "end" : "138394717",
   "start" : "137000000"
}
```

#### svarStart

* type: https://github.com/ga4gh/vr-spec/blob/116-patch-future-plans/schema/vr.json#118

- Information about range in which the start of the CNV has been mapped. This
  corresponds to the GA4GH GKS VRS "SimpleInterval".
- Optional pointer to fusion partner? Position or ID?
- The positions are annotated using a 0-based "interbase" coordinate system
(_cave_: differs from HGVS and browser displays).


##### `svarStart` Value Example  

```
{
   "end" : "750050000",
   "start" : "75000000"
}
```

#### variantType

* type: object

status as keyword or CURIE, quantitative parameters

##### `variantType` Value Example  

```
{
   "cn" : "3",
   "state" : "DUP"
}
```

