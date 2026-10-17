///|
using @rabbita {type Val, type Html, create_pure_state}

///|
using @html {div, h1, p, button}

///|
enum Msg {
  Inc
  Dec
}

///|
/// The page. It shows the shared contract version and a counter.
pub fn app() -> Val[Html] {
  let (model, emit) = create_pure_state(0, update=(model, msg) => {
    match msg {
      Inc => model + 1
      Dec => model - 1
    }
  })
  model.map(model => {
    div <| [
      h1("Moonbase"),
      p(@contracts.version()),
      p("\{model}"),
      button(on_click=emit(Inc), "+"),
      button(on_click=emit(Dec), "-"),
    ]
  })
}
