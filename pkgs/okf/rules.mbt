///|
fn metadata_error_message(error : MetadataError) -> (String, Int32?) {
  match error {
    InvalidYaml(line~, message~, ..) =>
      ("invalid frontmatter: \{message}", Some(line))
    Unterminated => ("the frontmatter block has no closing `---` line", Some(1))
  }
}

///|
/// Each document whose frontmatter block is invalid.
fn check_frontmatter_invalid(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for pair in ctx.knowledge.documents() {
    let (bundle, doc) = pair
    match doc.metadata_error() {
      Some(error) => {
        let (message, line) = metadata_error_message(error)
        out.push(
          Issue::at(
            bundle,
            doc,
            message,
            line?,
            hint="Fix the YAML between the `---` lines.",
          ),
        )
      }
      None => ()
    }
  }
  out
}

///|
/// Each concept without a frontmatter block, unless a profile derived its metadata.
fn check_concept_no_frontmatter(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for pair in ctx.knowledge.concepts() {
    let (bundle, doc) = pair
    if !doc.has_frontmatter_block() && !doc.is_derived() {
      out.push(
        Issue::at(
          bundle,
          doc,
          "the concept has no frontmatter",
          line=1,
          hint="Add a `---` block with at least `type`.",
        ),
      )
    }
  }
  out
}

///|
/// Each concept with valid metadata but no non-empty `type`.
fn check_concept_missing_type(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for pair in ctx.knowledge.concepts() {
    let (bundle, doc) = pair
    let has_metadata = doc.written_metadata() is Some(_) || doc.is_derived()
    if has_metadata && doc.concept_type() is None {
      out.push(
        Issue::at(
          bundle,
          doc,
          "the concept has no `type`",
          line=doc.metadata().line_of("type").unwrap_or(1),
        ),
      )
    }
  }
  out
}

///|
/// Each sub-index with a frontmatter block.
fn check_subindex_frontmatter(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for pair in ctx.knowledge.documents() {
    let (bundle, doc) = pair
    if doc.kind() is SubIndex && doc.has_frontmatter_block() {
      out.push(
        Issue::at(
          bundle,
          doc,
          "a sub-index has frontmatter",
          line=1,
          hint="Only the root index can carry `okf_version`.",
        ),
      )
    }
  }
  out
}

///|
/// Each root index frontmatter key other than `okf_version` and profile bundle keys.
fn check_root_index_keys(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for bundle in ctx.knowledge.bundles() {
    match bundle.root_index() {
      Some(doc) =>
        match doc.written_metadata() {
          Some(meta) =>
            for key in meta.keys() {
              if !ctx.vocabulary.knows_bundle_key(key) {
                out.push(
                  Issue::at(
                    bundle,
                    doc,
                    "the root index has the key `\{key}`",
                    line=meta.line_of(key).unwrap_or(1),
                  ),
                )
              }
            }
          None => ()
        }
      None => ()
    }
  }
  out
}

///|
/// Each log section whose heading is not a `YYYY-MM-DD` date.
fn check_log_undated(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for pair in ctx.knowledge.documents() {
    let (bundle, doc) = pair
    if doc.kind() is Log {
      for section in doc.log_model().undated_sections() {
        out.push(
          Issue::at(
            bundle,
            doc,
            "the log section `\{section.date}` is not a `YYYY-MM-DD` date",
            line=section.line,
          ),
        )
      }
    }
  }
  out
}

///|
/// The OKF v0.2 conformance rules (section 11): parseable frontmatter and a
/// non-empty `type` on each concept, and `index.md` and `log.md` in their formats.
pub fn okf_v02_conformance() -> RuleSet {
  RuleSet("okf-v0.2", [
    Rule("frontmatter-invalid", Error, check_frontmatter_invalid),
    Rule("concept-no-frontmatter", Error, check_concept_no_frontmatter),
    Rule("concept-missing-type", Error, check_concept_missing_type),
    Rule("subindex-has-frontmatter", Error, check_subindex_frontmatter),
    Rule("log-undated-section", Error, check_log_undated),
  ])
}

///|
fn concept_rule(
  check : (ValidationContext, Bundle, Document) -> Issue?,
) -> (ValidationContext) -> Array[Issue] {
  ctx => {
    let out = []
    for pair in ctx.knowledge.concepts() {
      match check(ctx, pair.0, pair.1) {
        Some(issue) => out.push(issue)
        None => ()
      }
    }
    out
  }
}

///|
fn has_metadata(doc : Document) -> Bool {
  doc.written_metadata() is Some(_) || doc.is_derived()
}

///|
fn check_missing_title(
  _ctx : ValidationContext,
  bundle : Bundle,
  doc : Document,
) -> Issue? {
  if has_metadata(doc) && doc.metadata().title() is None {
    Some(Issue::at(bundle, doc, "the concept has no `title`", line=1))
  } else {
    None
  }
}

///|
fn check_missing_description(
  _ctx : ValidationContext,
  bundle : Bundle,
  doc : Document,
) -> Issue? {
  if has_metadata(doc) && doc.metadata().description() is None {
    Some(Issue::at(bundle, doc, "the concept has no `description`", line=1))
  } else {
    None
  }
}

///|
fn check_status_unknown(
  _ctx : ValidationContext,
  bundle : Bundle,
  doc : Document,
) -> Issue? {
  match doc.metadata().status() {
    Some(Unknown(text)) =>
      Some(
        Issue::at(
          bundle,
          doc,
          "`status: \{text}` is not draft, stable or deprecated",
          line=doc.metadata().line_of("status").unwrap_or(1),
        ),
      )
    _ => None
  }
}

///|
fn check_stale(
  ctx : ValidationContext,
  bundle : Bundle,
  doc : Document,
) -> Issue? {
  let meta = doc.metadata()
  if meta.is_stale(ctx.now, options=bundle.options()) {
    let limit = meta.stale_after().unwrap_or("")
    Some(
      Issue::at(
        bundle,
        doc,
        "`stale_after: \{limit}` has passed",
        line=meta.line_of("stale_after").unwrap_or(1),
      ),
    )
  } else {
    None
  }
}

///|
fn check_unknown_keys(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for pair in ctx.knowledge.concepts() {
    let (bundle, doc) = pair
    match doc.written_metadata() {
      Some(meta) =>
        for key in meta.keys() {
          if !ctx.vocabulary.knows(key) {
            out.push(
              Issue::at(
                bundle,
                doc,
                "the key `\{key}` is not in the OKF or profile vocabulary",
                line=meta.line_of(key).unwrap_or(1),
              ),
            )
          }
        }
      None => ()
    }
  }
  out
}

///|
fn check_not_indexed(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for bundle in ctx.knowledge.bundles() {
    if bundle.indexes().is_empty() {
      continue
    }
    for doc in bundle.unindexed_concepts() {
      out.push(
        Issue::at(
          bundle,
          doc,
          "no index of the bundle links to this concept",
          hint="Add an entry to the nearest `index.md`.",
        ),
      )
    }
  }
  out
}

///|
fn check_drift(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for bundle in ctx.knowledge.bundles() {
    for drift in bundle.description_drift() {
      out.push(
        Issue::at(
          bundle,
          drift.index,
          "the entry for \{drift.concept.path()} does not match its description",
          line=drift.entry.line,
          hint="Use: \{drift.expected}",
        ),
      )
    }
  }
  out
}

///|
fn check_duplicate_titles(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for bundle in ctx.knowledge.bundles() {
    let seen : Map[String, Document] = Map([])
    for doc in bundle.concepts() {
      guard doc.metadata().title() is Some(title) else { continue }
      let key = title.to_lower()
      match seen.get(key) {
        Some(first) =>
          out.push(
            Issue::at(
              bundle,
              doc,
              "the title `\{title}` is also used by \{first.path()}",
            ),
          )
        None => seen[key] = doc
      }
    }
  }
  out
}

///|
fn check_broken_links(ctx : ValidationContext) -> Array[Issue] {
  ctx.graph
  .broken()
  .map(edge => {
    Issue(
      edge.from.bundle,
      edge.from.path.to_string(),
      "the link to `\{edge.link.destination}` does not resolve",
      line=edge.link.line,
    )
  })
}

///|
fn check_escaping_links(ctx : ValidationContext) -> Array[Issue] {
  ctx.graph
  .edges()
  .iter()
  .filter(e => e.escapes && e.link.kind is BundleRooted)
  .map(edge => {
    Issue(
      edge.from.bundle,
      edge.from.path.to_string(),
      "the link to `\{edge.link.destination}` leaves the bundle",
      line=edge.link.line,
    )
  })
  .collect()
}

///|
fn check_strays(ctx : ValidationContext) -> Array[Issue] {
  ctx.knowledge
  .strays()
  .iter()
  .map(path => {
    Issue("", path.to_string(), "the Markdown file belongs to no bundle")
  })
  .collect()
}

///|
fn check_log_order(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for pair in ctx.knowledge.documents() {
    let (bundle, doc) = pair
    if doc.kind() is Log {
      match doc.log_model().order_problem() {
        Some((a, b)) =>
          out.push(
            Issue::at(
              bundle,
              doc,
              "`\{a.date}` comes before the newer `\{b.date}`",
              line=b.line,
            ),
          )
        None => ()
      }
    }
  }
  out
}

///|
fn check_unknown_version(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for bundle in ctx.knowledge.bundles() {
    if !bundle.knows_version() {
      match bundle.root_index() {
        Some(doc) => {
          let version = bundle.okf_version().unwrap_or("")
          out.push(
            Issue::at(
              bundle,
              doc,
              "OKF version \{version} is not known; read with best effort",
            ),
          )
        }
        None => ()
      }
    }
  }
  out
}

///|
fn check_ignored_logs(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for bundle in ctx.knowledge.bundles() {
    for path in bundle.ignored_logs() {
      out.push(
        Issue(bundle.label(), path.to_string(), "the nested log is ignored"),
      )
    }
  }
  out
}

///|
fn check_unresolved_references(ctx : ValidationContext) -> Array[Issue] {
  let out = []
  for pair in ctx.knowledge.documents() {
    let (bundle, doc) = pair
    for r in typed_references(ctx.knowledge, bundle, doc, profiles=ctx.profiles) {
      if !r.is_resolved() {
        out.push(
          Issue::at(
            bundle,
            doc,
            "`\{r.key}: \{r.value}` does not resolve",
            line?=r.line,
          ),
        )
      }
    }
  }
  out
}

///|
/// Advisory rules. They report quality problems that OKF v0.2 tolerates; the
/// caller sets their severity with `ValidationConfig`.
pub fn advisory() -> RuleSet {
  RuleSet("okf-advisory", [
    Rule("concept-missing-title", Warning, concept_rule(check_missing_title)),
    Rule(
      "concept-missing-description",
      Warning,
      concept_rule(check_missing_description),
    ),
    Rule("status-unknown", Warning, concept_rule(check_status_unknown)),
    Rule("stale-after-passed", Warning, concept_rule(check_stale)),
    Rule("frontmatter-unknown-key", Info, check_unknown_keys),
    Rule("index-frontmatter-key", Warning, check_root_index_keys),
    Rule("concept-not-indexed", Warning, check_not_indexed),
    Rule("index-description-drift", Warning, check_drift),
    Rule("duplicate-title", Warning, check_duplicate_titles),
    Rule("link-broken", Warning, check_broken_links),
    Rule("link-escapes-bundle", Warning, check_escaping_links),
    Rule("reference-unresolved", Warning, check_unresolved_references),
    Rule("stray-markdown", Warning, check_strays),
    Rule("log-not-newest-first", Warning, check_log_order),
    Rule("okf-version-unknown", Info, check_unknown_version),
    Rule("log-ignored", Info, check_ignored_logs),
  ])
}
