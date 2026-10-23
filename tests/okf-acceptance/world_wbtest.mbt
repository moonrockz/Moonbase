///|
/// The scenario state of the OKF acceptance suites. Each scenario owns its World.
struct OkfWorld {
  files : Array[@okf.FileEntry]
  mut options : @okf.Options
  mut clock : @okf.FixedClock
  profiles : Array[&@okf.Profile]
  mut knowledge : @okf.Knowledge?
  mut report : @okf.Report?
  overrides : Array[(String, @okf.Severity)]
  disabled : Array[String]
  mut text : String
  mut changed : Bool
  mut plan : @edit.EditPlan?
  mut failure : String?
}

///|
fn OkfWorld::OkfWorld() -> OkfWorld {
  {
    files: [],
    options: @okf.Options::default(),
    clock: @okf.FixedClock(@okf.Instant::of_millis(0L)),
    profiles: [],
    knowledge: None,
    report: None,
    overrides: [],
    disabled: [],
    text: "",
    changed: false,
    plan: None,
    failure: None,
  }
}

///|
fn OkfWorld::set(self : OkfWorld) -> @okf.DocumentSet {
  @okf.DocumentSet(self.files)
}

///|
fn OkfWorld::add(self : OkfWorld, path : String, text : String) -> Unit raise {
  self.files.push({ path: @okf.StorePath(path), content: Text(text), })
}

///|
fn OkfWorld::loaded(self : OkfWorld) -> @okf.Knowledge raise {
  match self.knowledge {
    Some(k) => k
    None => fail("this step needs loaded knowledge")
  }
}

///|
fn OkfWorld::only_bundle(self : OkfWorld) -> @okf.Bundle raise {
  match self.loaded().bundles().iter().collect() {
    [b] => b
    list => fail("expected one bundle, found \{list.length()}")
  }
}

///|
/// Finds a document by `label:/path`, or by `/path` in the only bundle.
fn OkfWorld::doc(
  self : OkfWorld,
  reference : String,
) -> (@okf.Bundle, @okf.Document) raise {
  let k = self.loaded()
  let (label, path) = match reference.find(":/") {
    Some(i) => (Some(reference[:i].to_owned()), reference[i + 1:].to_owned())
    None => (None, reference)
  }
  match k.find_document(path, bundle?=label) {
    Found(pair) => pair
    NotFound => fail("no document \{reference}")
    Ambiguous(_) => fail("\{reference} is ambiguous")
  }
}

///|
fn OkfWorld::key(self : OkfWorld, reference : String) -> @okf.DocKey raise {
  let (b, d) = self.doc(reference)
  @okf.DocKey::of(b, d)
}

///|
fn OkfWorld::validated(self : OkfWorld) -> @okf.Report raise {
  match self.report {
    Some(r) => r
    None => fail("this step needs a validation report")
  }
}

///|
/// Splits `a, b, c` into items; an empty text gives no items.
fn items(text : String) -> Array[String] {
  if text.trim(chars=" ").length() == 0 {
    []
  } else {
    text.split(",").map(s => s.trim(chars=" ").to_owned()).collect()
  }
}

///|
fn severity_of(text : String) -> @okf.Severity raise {
  match text {
    "error" => Error
    "warning" | "warn" => Warning
    "info" | "information" => Info
    _ => fail("unknown severity \{text}")
  }
}

///|
fn kind_name(kind : @okf.DocKind) -> String {
  match kind {
    RootIndex => "root index"
    SubIndex => "sub-index"
    Log => "log"
    Concept => "concept"
  }
}

///|
fn link_kind_name(kind : @okf.LinkKind) -> String {
  match kind {
    External => "external"
    Anchor => "anchor"
    BundleRooted => "bundle-rooted"
    Relative => "relative"
  }
}

///|
fn tier_name(tier : @okf.TrustTier) -> String {
  match tier {
    Unverified => "unverified"
    MachineConfirmed => "machine-confirmed"
    HumanReviewed => "human-reviewed"
  }
}

///|
fn table_rows(
  table : @moonspec.DataTable,
  columns : Array[String],
) -> Array[Array[String]] {
  table.as_maps().map(row => columns.map(c => row.get(c).unwrap_or("")))
}

///|
impl @moonspec.World for OkfWorld with fn configure(self, setup) {
  configure_given(self, setup)
  configure_documents(self, setup)
  configure_relationships(self, setup)
  configure_indexes(self, setup)
  configure_validation(self, setup)
  configure_editing(self, setup)
}

///|
fn configure_given(world : OkfWorld, setup : @moonspec.Setup) -> Unit {
  setup.given2("the file {string}:", (path : String, doc : @moonspec.DocString) => {
    world.add(path, doc.content)
  })
  setup.given2("the file {string} with the text {string}", (
    path : String,
    text : String,
  ) => {
    world.add(
      path,
      text.replace_all(old="\\n", new="\n").replace_all(old="\\\"", new="\""),
    )
  })
  setup.given0("the options use the bundle root as the link base", () => {
    world.options = world.options.update(link_base=BundleRoot)
  })
  setup.given0("the options set no status default", () => {
    world.options = world.options.update(status_default=None)
  })
  setup.given0("the options accept date-only instants", () => {
    world.options = world.options.update(date_only_instants=true)
  })
  setup.given0("the options load root logs only", () => {
    world.options = world.options.update(nested_logs=RootOnly)
  })
  setup.given0("index links count as backlinks", () => {
    world.options = world.options.update(index_links_count=true)
  })
  setup.given1("the clock is {string}", (text : String) => {
    world.clock = @okf.FixedClock::at(text)
  })
  setup.when1("the bundle at {string} is loaded", (root : String) => {
    let root = items(root.replace_all(old="/", new=","))
    world.knowledge = Some(
      @okf.Knowledge(
        [
          @okf.load_bundle(
            world.set(),
            root~,
            options=world.options,
            profiles=world.profiles,
          ),
        ],
        options=world.options,
      ),
    )
  })
  setup.when1("the bundles under {string} are discovered", (under : String) => {
    let under = items(under.replace_all(old="/", new=","))
    world.knowledge = Some(
      @okf.discover(
        world.set(),
        under~,
        options=world.options,
        profiles=world.profiles,
      ),
    )
  })
}
