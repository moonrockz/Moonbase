///|
fn main {
  match run(program_args()) {
    Text(text) => println(text)
    Unknown(command) => {
      eprintln("mission-control: unknown command '\{command}'")
      eprintln(usage())
      @sys.exit(1)
    }
  }
}
