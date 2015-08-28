// (C) Uri Wilensky. https://github.com/NetLogo/Tortoise

package org.nlogo.tortoise

import
  WidgetCompilation.PlotWidgetCompilation

import
  jsengine.Nashorn

import
  json.WidgetSamples.{
    pen  => penWidget,
    plot => plotWidget
  }

import
  org.scalatest.{ FunSuite, OneInstancePerTest }

import
  scalaz.{ NonEmptyList, Scalaz, ValidationNel },
    Scalaz.ToValidationOps

class PlotCompilerTest extends FunSuite with OneInstancePerTest {
  class FakeOutput {
    var alertsReceived = Seq[String]()

    def alert(s: String): Unit =
      alertsReceived = alertsReceived :+ s
  }

  lazy val output = new FakeOutput()

  lazy val nashornEngine = {
    val e = new Nashorn().engine
    e.put("fakeOutput", output)
    e.eval("modelConfig = { output: fakeOutput };")
    e.eval("modelPlotOps = {};")
    e.eval("function PlotOps() {};")
    e.eval("function Plot() {};")
    e
  }

  def compiledPlot(compilationV: ValidationNel[Exception, PlotWidgetCompilation]) =
    new CompiledPlot(plotWidget, "abc", compilationV)

  def plotJs(plot: CompiledPlot): String =
    PlotCompiler.formatPlots(Seq(plot)).filter(_.provides == "modelConfig.plots").head.toJS

  def compilePlotWidgetV(compilationV: ValidationNel[Exception, PlotWidgetCompilation]): String =
    plotJs(compiledPlot(compilationV))

  test("returns valid javascript when plots have errors") {
    val generatedJs =
      compilePlotWidgetV(new Exception("plot abc has problems").failureNel)
    nashornEngine.eval(generatedJs)
    assert(output.alertsReceived.head == "plot abc has problems")
  }

  test("returns valid javascript when pens have errors") {
    val errantPen = new CompiledPen(penWidget, new Exception("pen has problems").failureNel)
    val widgetCompilation =
      PlotWidgetCompilation("function() {}", "function() {}", Seq(errantPen)).successNel
    val generatedJs = compilePlotWidgetV(widgetCompilation)
    nashornEngine.eval(generatedJs)
    assert(output.alertsReceived.head == "pen has problems")
  }

  test("returns multiple errors when there are multiple pen errors") {
    val errantPens = new CompiledPen(penWidget, NonEmptyList(new Exception("pen a has problems"), new Exception("pen b has problems")).failure)
    val widgetCompilation =
      PlotWidgetCompilation("function() {}", "function() {}", Seq(errantPens)).successNel
    val generatedJs = compilePlotWidgetV(widgetCompilation)
    nashornEngine.eval(generatedJs)
    assert(output.alertsReceived.head == "pen a has problems, pen b has problems")
  }

  test("returns valid javascript when plots are correct") {
    val widgetCompilation =
      PlotWidgetCompilation("function() {}", "function() {}", Seq()).successNel
    val generatedJs = compilePlotWidgetV(widgetCompilation)
    nashornEngine.eval(generatedJs)
    assert(output.alertsReceived.isEmpty)
  }
}