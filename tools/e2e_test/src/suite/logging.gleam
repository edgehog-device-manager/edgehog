import gleam/io

pub fn pass(test_name: String) -> Nil {
  io.println("--- PASS " <> test_name <> " ---")
}

pub fn fail(test_name: String) -> Nil {
  io.println("xxx FAIL " <> test_name <> " xxx")
}
