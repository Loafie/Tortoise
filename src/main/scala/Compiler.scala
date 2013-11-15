// (C) Uri Wilensky. https://github.com/NetLogo/NetLogo

package org.nlogo.tortoise

import org.nlogo.{ api, compile => ast, nvm, workspace },
   nvm.FrontEndInterface.{ ProceduresMap, NoProcedures },
   org.nlogo.shape.{LinkShape, VectorShape}

import collection.JavaConverters._

object Compiler {

  val frontEnd: ast.FrontEndInterface = ast.front.FrontEnd

  // three main entry points. input is NetLogo, result is JavaScript.

  def compileReporter(logo: String,
    oldProcedures: ProceduresMap = NoProcedures,
    program: api.Program = api.Program.empty()): String =
    compile(logo, commands = false, oldProcedures, program)

  def compileCommands(logo: String,
    oldProcedures: ProceduresMap = NoProcedures,
    program: api.Program = api.Program.empty()): String =
    compile(logo, commands = true, oldProcedures, program)

  def compileProcedures(
      logo: String,
      interfaceGlobals: Seq[String] = Seq(),
      interfaceGlobalCommands: String = "",
      dimensions: api.WorldDimensions = api.WorldDimensions.square(0),
      turtleShapeList: api.ShapeList = new api.ShapeList(api.AgentKind.Turtle),
      linkShapeList: api.ShapeList = new api.ShapeList(api.AgentKind.Link))
      : (String, api.Program, ProceduresMap) = {
    // (Seq[ProcedureDefinition], StructureParser.Results)
    val (defs, sp) =
      frontEnd.frontEnd(logo,
        program = api.Program.empty.copy(interfaceGlobals = interfaceGlobals))
    val js =
      new RuntimeInit(sp.program, dimensions, turtleShapeList, linkShapeList).init +
        defs.map(compileProcedureDef).mkString("", "\n", "\n") +
        compileCommands(interfaceGlobalCommands, program = sp.program)
    if (sp.program.linkBreeds.nonEmpty)
      throw new IllegalArgumentException("unknown language feature: link breeds")
    (js, sp.program, sp.procedures)
  }

  private def compileProcedureDef(pd: ast.ProcedureDefinition): String = {
    val name = ident(pd.procedure.name)
    val body = generate(pd.statements)
    val args = pd.procedure.args.map(ident).mkString(", ")
    s"function $name ($args) {\n$body\n};"
  }

  // bogus, will need work - ST 9/13/13
  def ident(s: String) =
    s.replaceAll("-", "_")
     .replaceAll("\\?", "_P")

  // How this works:
  // - the header/footer stuff wraps the code in `to` or `to-report`
  // - the compile returns a Seq, whose head is a ProcedureDefinition
  //   containing some Statements (the procedure body)
  // - in the reporter case, the procedure body starts with the
  //   `__observer-code` command followed by the `report` command, so the
  //   actual reporter is the first (and only) argument to `report`

  def compile(logo: String, commands: Boolean,
      oldProcedures: ProceduresMap = NoProcedures,
      program: api.Program = api.Program.empty()): String = {
    val wrapped =
      workspace.Evaluator.getHeader(api.AgentKind.Observer, commands) +
        logo + workspace.Evaluator.getFooter(commands)
    val (defs, _) = frontEnd.frontEnd(wrapped, oldProcedures, program)  // Seq[ProcedureDefinition]
    if (commands) generate(defs.head.statements)
    else generate(defs.head.statements.tail.head.args.head)
  }

  def compileLiteral(x: AnyRef): String = x match {
    case ll: api.LogoList =>
      ll.map(compileLiteral).mkString("[", ", ", "]")
    case x =>
      api.Dump.logoObject(x, readable = true, exporting = false)
  }

  def generate(node: ast.AstNode): String = node match {
    case stmts: ast.Statements =>
      stmts.map(Prims.generateCommand)
        .filter(_.nonEmpty)
        .mkString("\n")
    case block: ast.ReporterBlock =>
      generate(block.app)
    case app: ast.ReporterApp =>
      Prims.generateReporter(app)
    case block: ast.CommandBlock =>
      Compiler.generate(block.statements)
  }

}