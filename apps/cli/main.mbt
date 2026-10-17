///|
fn main {
  match run(program_args()) {
    Text(text) => println(text)
    Unknown(command) => {
      eprintln("moonbase: unknown command '\{command}'")
      eprintln(usage())
      @sys.exit(1)
    }
  }
}
