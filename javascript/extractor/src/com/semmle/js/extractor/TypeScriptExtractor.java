package com.semmle.js.extractor;

import java.io.File;

import com.semmle.js.extractor.ExtractorConfig.ECMAVersion;
import com.semmle.js.extractor.ExtractorConfig.SourceType;
import com.semmle.js.parser.JSParser.Result;
import com.semmle.ts.extractor.TypeScriptParser;
import com.semmle.js.parser.ParseError;

public class TypeScriptExtractor implements IExtractor {
  private final JSExtractor jsExtractor;
  private final ExtractorState state;

  public TypeScriptExtractor(ExtractorConfig config, ExtractorState state) {
    this.jsExtractor = new JSExtractor(config);
    this.state = state;
  }

  @Override
  public LoCInfo extract(TextualExtractor textualExtractor) {
    LocationManager locationManager = textualExtractor.getLocationManager();
    String source = textualExtractor.getSource();
    File sourceFile = textualExtractor.getExtractedFile();
    Result res = state.getTypeScriptParser().parse(sourceFile, source, textualExtractor.getMetrics());
    ScopeManager scopeManager =
        new ScopeManager(textualExtractor.getTrapwriter(), ECMAVersion.ECMA2017);
    try {
      FileSnippet snippet = state.getSnippets().get(sourceFile.toPath());
      SourceType sourceType = snippet != null ? snippet.getSourceType() : jsExtractor.establishSourceType(source, false);
      int toplevelKind = snippet != null ? snippet.getTopLevelKind() : 0;
      return jsExtractor.extract(textualExtractor, source, toplevelKind, scopeManager, sourceType, res).snd();
    } catch (ParseError e) {
      e.setPosition(locationManager.translatePosition(e.getPosition()));
      throw e.asUserError();
    }
  }
}
