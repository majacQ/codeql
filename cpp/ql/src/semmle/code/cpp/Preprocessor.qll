import semmle.code.cpp.Location
import semmle.code.cpp.Element

/**
 * A C/C++ preprocessor directive.
 *
 * For example: `#ifdef`, `#line`, or `#pragma`.
 */
class PreprocessorDirective extends Locatable, @preprocdirect {
  override string toString() { result = "Preprocessor directive" }
  override Location getLocation() { preprocdirects(underlyingElement(this),_,result) }
  string getHead() { preproctext(underlyingElement(this),result,_) }

  /**
   * Gets a preprocessor branching directive whose condition affects
   * whether this directive is performed.
   *
   * From a lexical point of view, this returns all `#if`, `#ifdef`,
   * `#ifndef`, or `#elif` directives which occur before this directive and
   * have a matching `#endif` which occurs after this directive.
   */
  PreprocessorBranch getAGuard() {
    exists(PreprocessorEndif e, int line |
      result.getEndIf() = e and
      e.getFile() = getFile() and
      result.getFile() = getFile() and
      line = this.getLocation().getStartLine() and
      result.getLocation().getStartLine() < line and
      line < e.getLocation().getEndLine()
    )
  }
}

/**
 * A C/C++ preprocessor branch related directive: `#if`, `#ifdef`,
 * `#ifndef`, `#elif`, `#else` or `#endif`.
 */
abstract class PreprocessorBranchDirective extends PreprocessorDirective {
  /**
   * Gets the `#if`, `#ifdef` or `#ifndef` directive which matches this
   * branching directive.
   *
   * If this branch directive was unbalanced, then there will be no
   * result. Conversely, if the branch matches different `#if` directives
   * in different translation units, then there can be more than one
   * result.
   */
  PreprocessorBranch getIf() {
    result = (PreprocessorIf)this or
    result = (PreprocessorIfdef)this or
    result = (PreprocessorIfndef)this or
    preprocpair(unresolveElement(result), underlyingElement(this))
  }

  /**
   * Gets the `#endif` directive which matches this branching directive.
   *
   * If this branch directive was unbalanced, then there will be no
   * result. Conversely, if the branch matched different `#endif`
   * directives in different translation units, then there can be more than
   * one result.
   */
  PreprocessorEndif getEndIf() {
    preprocpair(unresolveElement(getIf()), unresolveElement(result))
  }

  /**
   * Gets the next `#elif`, `#else` or `#endif` matching this branching
   * directive.
   *
   * For example `somePreprocessorBranchDirective.getIf().getNext()` gets
   * the second directive in the same construct as
   * `somePreprocessorBranchDirective`.
   */
  PreprocessorBranchDirective getNext() {
    getIf() = result.getIf() and
    getLocation().getStartLine() < result.getLocation().getStartLine() and
    not exists(PreprocessorBranchDirective other |
      getIf() = other.getIf() and
      getLocation().getStartLine() < other.getLocation().getStartLine() and
      other.getLocation().getStartLine() < result.getLocation().getStartLine()
    )
  }
}

/**
 * A C/C++ preprocessor branching directive: `#if`, `#ifdef`, `#ifndef`, or
 * `#elif`.
 *
 * A branching directive can have its condition evaluated at compile-time,
 * and as a result, the preprocessor will either take the branch, or not
 * take the branch.
 *
 * However, there are also situations in which a branch's condition isn't
 * evaluated.  The obvious case of this is when the directive is contained
 * within a branch which wasn't taken. There is also a much more subtle
 * case involving header guard branches: suitably clever compilers can
 * notice that a branch is a header guard, and can then subsequently ignore
 * a `#include` for the file being guarded. It is for this reason that
 * `wasTaken()` always holds on header guard branches, but `wasNotToken()`
 * rarely holds on header guard branches.
 */
class PreprocessorBranch extends PreprocessorBranchDirective, @ppd_branch {
  /**
   * Holds if at least one translation unit evaluated this directive's
   * condition and subsequently took the branch.
   */
  predicate wasTaken() {
    preproctrue(underlyingElement(this))
  }

  /**
   * Holds if at least one translation unit evaluated this directive's
   * condition but then didn't take the branch.
   *
   * If `#else` is the next matching directive, then this means that the
   * `#else` was taken instead.
   */
  predicate wasNotTaken() {
    preprocfalse(underlyingElement(this))
  }

  /**
   * Holds if this directive was either taken by all translation units
   * which evaluated it, or was not taken by any translation unit which
   * evaluated it.
   */
  predicate wasPredictable() {
    not ( wasTaken() and wasNotTaken() )
  }
}

/**
 * A C/C++ preprocessor `#if` directive.
 *
 * For the related notion of a directive which causes branching (which
 * includes `#if`, plus also `#ifdef`, `#ifndef`, and `#elif`), see
 * `PreprocessorBranch`.
 */
class PreprocessorIf extends PreprocessorBranch, @ppd_if {
  override string toString() { result = "#if " + this.getHead() }
}

/**
 * A C/C++ preprocessor `#ifdef` directive.
 *
 * The syntax `#ifdef X` is shorthand for `#if defined(X)`.
 */
class PreprocessorIfdef extends PreprocessorBranch, @ppd_ifdef {
  override string toString() { result = "#ifdef " + this.getHead() }
}

/**
 * A C/C++ preprocessor `#ifndef` directive.
 *
 * The syntax `#ifndef X` is shorthand for `#if !defined(X)`.
 */
class PreprocessorIfndef extends PreprocessorBranch, @ppd_ifndef {
  override string toString() { result = "#ifndef " + this.getHead() }
}

/**
 * A C/C++ preprocessor `#else` directive.
 */
class PreprocessorElse extends PreprocessorBranchDirective, @ppd_else {
  override string toString() { result = "#else" }
}

/**
 * A C/C++ preprocessor `#elif` directive.
 */
class PreprocessorElif extends PreprocessorBranch, @ppd_elif {
  override string toString() { result = "#elif " + this.getHead() }
}

/**
 * A C/C++ preprocessor `#endif` directive.
 */
class PreprocessorEndif extends PreprocessorBranchDirective, @ppd_endif {
  override string toString() { result = "#endif" }
}

/**
 * A C/C++ preprocessor `#warning` directive.
 */
class PreprocessorWarning extends PreprocessorDirective, @ppd_warning {
  override string toString() { result = "#warning " + this.getHead() }
}

/**
 * A C/C++ preprocessor `#error` directive.
 */
class PreprocessorError extends PreprocessorDirective, @ppd_error {
  override string toString() { result = "#error " + this.getHead() }
}

/**
 * A C/C++ preprocessor `#undef` directive.
 */
class PreprocessorUndef extends PreprocessorDirective, @ppd_undef {
  override string toString() { result = "#undef " + this.getHead() }

  /**
   * Gets the name of the macro that is undefined.
   */
  string getName() {
    result = getHead()
  }
}

/**
 * A C/C++ preprocessor `#pragma` directive.
 */
class PreprocessorPragma extends PreprocessorDirective, @ppd_pragma {
  override string toString() { result = "#pragma " + this.getHead() }
}

/**
 * A C/C++ preprocessor `#line` directive.
 */
class PreprocessorLine extends PreprocessorDirective, @ppd_line {
  override string toString() { result = "#line " + this.getHead() }
}

/**
 * Holds if the preprocessor branch `pbd` is on line `pbdStartLine` in file `file`.
 */
private predicate pbdLocation(PreprocessorBranchDirective pbd, string file, int pbdStartLine) {
  pbd.getLocation().hasLocationInfo(file, pbdStartLine, _, _, _)
}

/**
 * Holds if the body of the function `f` is on lines `fBlockStartLine` to `fBlockEndLine` in file `file`.
 */
private predicate functionLocation(Function f, string file, int fBlockStartLine, int fBlockEndLine) {
  f.getBlock().getLocation().hasLocationInfo(file, fBlockStartLine, _, fBlockEndLine, _)
}

/**
 * Holds if the function `f` is inside a preprocessor branch that may have code in another arm.
 */
predicate definedInIfDef(Function f) {
  exists(PreprocessorBranchDirective pbd, string file, int pbdStartLine, int pbdEndLine, int fBlockStartLine,
      int fBlockEndLine  |
    functionLocation(f, file, fBlockStartLine, fBlockEndLine) and
    pbdLocation(pbd, file, pbdStartLine) and
    pbdLocation(pbd.getNext(), file, pbdEndLine) and
    pbdStartLine <= fBlockStartLine and
    pbdEndLine >= fBlockEndLine and
    // pbd is a preprocessor branch where multiple branches exist
    (
      pbd.getNext() instanceof PreprocessorElse or
      pbd instanceof PreprocessorElse or
      pbd.getNext() instanceof PreprocessorElif or
      pbd instanceof PreprocessorElif
    )
  )
}

/**
 * Holds if the function `f`, or a function called by it, contains
 * code excluded by the preprocessor.
 */
predicate containsDisabledCode(Function f) {
  // `f` contains a preprocessor branch that was not taken
  exists(PreprocessorBranchDirective pbd, string file, int pbdStartLine, int fBlockStartLine, int fBlockEndLine |
      functionLocation(f, file, fBlockStartLine, fBlockEndLine) and
    pbdLocation(pbd, file, pbdStartLine) and
    pbdStartLine <= fBlockEndLine and
    pbdStartLine >= fBlockStartLine and
    (
      pbd.(PreprocessorBranch).wasNotTaken() or

      // an else either was not taken, or it's corresponding branch
      // was not taken.
      pbd instanceof PreprocessorElse
    )
  ) or
  // recurse into function calls
  exists(FunctionCall fc |
    fc.getEnclosingFunction() = f and
    containsDisabledCode(fc.getTarget())
  )
}
