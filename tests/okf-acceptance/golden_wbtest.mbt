///|
test "discovery matches morphir kb list" {
  let knowledge = morphir_knowledge()
  let golden = read_golden("list.json")
  guard golden is { "bundles": Array(bundles), .. } else { fail("bad golden") }
  let expected = bundles.map(b => {
    guard b
      is {
        "label": String(label),
        "group": String(group),
        "okfVersion": String(version),
        "concepts": Number(concepts, ..),
        "subIndexes": Number(sub, ..),
        "hasLog": hasLog,
        ..
      } else {
      fail("bad bundle")
    }
    (
      label,
      group,
      version,
      concepts.to_int(),
      sub.to_int(),
      hasLog == Json::boolean(true),
    )
  })
  let actual = knowledge
    .bundles()
    .map(b => {
      (
        b.label(),
        b.group().join("/"),
        b.okf_version().unwrap_or(""),
        b.concepts().length(),
        b.indexes().filter(d => d.kind() is SubIndex).length(),
        b.root_log() is Some(_),
      )
    })
    .iter()
    .collect()
  assert_eq(actual, expected)
  assert_eq(knowledge.strays().length(), 0)
}

///|
/// The golden findings of `morphir kb check` for the given checks, as
/// (severity, check, path, line).
fn golden_findings(
  checks : Array[String],
) -> Array[(String, String, String, Int32)] raise {
  guard read_golden("check.json") is { "findings": Array(findings), .. } else {
    fail("bad golden")
  }
  let out = []
  for f in findings {
    guard f
      is {
        "severity": String(severity),
        "check": String(check),
        "path": String(path),
        "line": line,
        ..
      } else {
      fail("bad finding")
    }
    if checks.contains(check) {
      let line = match line {
        Number(n, ..) => n.to_int()
        _ => 0
      }
      out.push((severity, check, path, line))
    }
  }
  out.sort()
  out
}

///|
fn as_morphir_rows(
  report : @okf.Report,
  checks : Array[String],
) -> Array[(String, String, String, Int32)] {
  let out = []
  for f in report.findings() {
    if checks.contains(f.rule) {
      out.push(
        (
          f.severity.to_string(),
          f.rule,
          "kb/bundles/" + f.bundle + f.path,
          f.line.unwrap_or(0),
        ),
      )
    }
  }
  out.sort()
  out
}

///|
test "broken links and drift match morphir kb check" {
  let knowledge = morphir_knowledge()
  let checks = ["link-broken", "index-description-drift"]
  let report = @okf.validate(
    knowledge,
    [@okf.okf_v02_conformance(), @okf.advisory()],
    @okf.FixedClock::at("2026-10-23T00:00:00Z"),
    config=@okf.ValidationConfig(overrides=[("link-broken", Error)]),
  )
  assert_eq(as_morphir_rows(report, checks), golden_findings(checks))
  assert_eq(report.count(Error), 32)
}
