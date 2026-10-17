///|
#cfg(not(target="js"))
fn program_args() -> Array[String] {
  @env.args()[1:].to_owned()
}
