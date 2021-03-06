// (C) Uri Wilensky. https://github.com/NetLogo/Tortoise

package org.nlogo.tortoise.nlw
package dock

class TestStrings extends DockingSuite {

  test("word 0") { implicit fixture => import fixture._
    compare("(word)")
  }

  test("word 1") { implicit fixture => import fixture._
    compare("(word 1)")
  }

  test("word") { implicit fixture => import fixture._
    compare("(word 1 2 3)") // 123, and hopefully not, god forbid, 6
  }

  test("word on list") { implicit fixture => import fixture._
    compare("(word [1 [2 [3 4] 5] 6])")
  }

  test("print list") { implicit fixture => import fixture._
    testCommand("output-print [1 [2 [3 4] 5] 6]")
  }

  test("length") { implicit fixture => import fixture._
    compare("length \"\"")
    compare("length \"HELLO WORLD\"")
  }
}
