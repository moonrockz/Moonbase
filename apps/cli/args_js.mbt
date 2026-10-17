///|
#cfg(target="js")
fn program_args() -> Array[String] {
  @env.args()[2:].to_owned()
}
