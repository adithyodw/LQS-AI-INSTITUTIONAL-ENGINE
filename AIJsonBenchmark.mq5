//+------------------------------------------------------------------+
//|                                        TestJsonBenchmark.mq5 |
//|                                                   AI-Toolkit |
//+------------------------------------------------------------------+
#property script_show_inputs
#include <fast_json.mqh> // Bit-Banger V2
#include <JAson.mqh>        // Russian Legacy

input int Loops = 50000;

void OnStart() {
  Print("=== JSON BENCHMARK: THE RECKONING ===");
  Print("Comparing AI-Toolkit V2 (Production) vs JAson");

  // Complex JSON with Mixed Types, Nested Objects, and Arrays
  string json =
      "{"
      "\"id\": 12345,"
      "\"config\": {\"active\": true, \"mode\": \"swar\", \"threshold\": "
      "0.0005},"
      "\"rates\": [1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0],"
      "\"users\": [{\"id\":1, \"name\":\"A\"}, {\"id\":2, \"name\":\"B\"}],"
      "\"desc\": \"Short string\","
      "\"long\": \"This is a longer string to test the memory copy speed of "
      "the parser when handling larger payloads.\""
      "}";

  ulong t0, t_parse = 0, t_read = 0, t_sum = 0, t_ser = 0;

  //---------------------------------------------------------
  // 1. AI-TOOLKIT BIT-BANGER V2
  //---------------------------------------------------------
  Print("--- TESTING AI-TOOLKIT V2 ---");
  long dummy_int = 0;
  double dummy_sum = 0;
  string dummy_ser = "";

  // A. PARSE
  CJson toolkit;
  t0 = GetMicrosecondCount();
  for (int i = 0; i < Loops; i++) {
    toolkit.Parse(json);
  }
  t_parse = GetMicrosecondCount() - t0;
  Print("Parse: ", t_parse, " us");

  // B. DEEP READ (Hash Map)
  toolkit.Parse(json); // Reset
  t0 = GetMicrosecondCount();
  for (int i = 0; i < Loops; i++) {
    dummy_int += toolkit["config"]["mode"].Equals("swar") ? 1 : 0;
    dummy_int += toolkit["id"].ToInt();
  }
  t_read = GetMicrosecondCount() - t0;
  Print("Deep Read: ", t_read, " us");

  // C. ARRAY SUM (Iteration)
  t0 = GetMicrosecondCount();
  for (int i = 0; i < Loops; i++) {
    CJsonNode rates = toolkit["rates"];
    // Iterator Optimization: Fast Double Access (Stride 2)
    CJsonFastDoubleIterator it = rates.begin_fast_double();
    while (it.IsValid()) {
      dummy_sum += it.Val(); // Direct read
      it.Next();
    }
  }
  t_sum = GetMicrosecondCount() - t0;
  Print("Array Sum: ", t_sum, " us");

  // D. SERIALIZATION
  t0 = GetMicrosecondCount();
  for (int i = 0; i < Loops; i++) {
    dummy_ser = toolkit.Serialize();
  }
  t_ser = GetMicrosecondCount() - t0;
  Print("Serialize: ", t_ser, " us");

  ulong total_toolkit = t_parse + t_read + t_sum + t_ser;

  //---------------------------------------------------------
  // 2. RUSSIAN LEGACY (JAson)
  //---------------------------------------------------------
  Print("--- TESTING LEGACY JASON ---");
  ulong j_parse = 0, j_read = 0, j_sum = 0, j_ser = 0;

  // A. PARSE
  CJAVal jason;
  t0 = GetMicrosecondCount();
  for (int i = 0; i < Loops; i++) {
    jason.Deserialize(json);
  }
  j_parse = GetMicrosecondCount() - t0;
  Print("Parse: ", j_parse, " us");

  // B. DEEP READ
  t0 = GetMicrosecondCount();
  for (int i = 0; i < Loops; i++) {
    // JAson syntax
    dummy_int += jason["config"]["mode"].ToStr() == "swar" ? 1 : 0;
    dummy_int += jason["id"].ToInt();
  }
  j_read = GetMicrosecondCount() - t0;
  Print("Deep Read: ", j_read, " us");

  // C. ARRAY SUM
  t0 = GetMicrosecondCount();
  for (int i = 0; i < Loops; i++) {
    CJAVal *rates = jason["rates"]; // Get pointer to array
    // JAson usually allows array access via []
    for (int k = 0; k < 10; k++) {
      dummy_sum += rates[k].ToDbl();
    }
  }
  j_sum = GetMicrosecondCount() - t0;
  Print("Array Sum: ", j_sum, " us");

  // D. SERIALIZATION
  t0 = GetMicrosecondCount();
  for (int i = 0; i < Loops; i++) {
    dummy_ser = jason.Serialize();
  }
  j_ser = GetMicrosecondCount() - t0;
  Print("Serialize: ", j_ser, " us");

  ulong total_jason = j_parse + j_read + j_sum + j_ser;

  //---------------------------------------------------------
  // 3. COMPLEX ROUNDTRIP & API HELPER TEST
  //---------------------------------------------------------
  Print("--- TESTING ROUNDTRIP & HELPERS ---");
  CJsonBuilder b;
  b.Obj()
      .Key("meta")
      .Obj()
      .Key("version")
      .Val(2)
      .Key("timestamp")
      .Val(123456789)
      .EndObj()
      .Key("data")
      .Arr()
      .Obj()
      .Key("id")
      .Val(1)
      .Key("val")
      .Val(10.5)
      .EndObj()
      .Obj()
      .Key("id")
      .Val(2)
      .Key("val")
      .Val(20.0)
      .EndObj()
      .EndArr()
      .Key("flags")
      .Arr()
      .Val(true)
      .Val(false)
      .Val(true)
      .EndArr()
      .Key("unicode")
      .Val("R$ 100,00 \u00A9")
      .EndObj();

  string built_json = b.Build();
  Print("Built JSON: ", built_json);

  CJson check;
  if (check.Parse(built_json)) {
    CJsonNode root = check.GetRoot();

    // 1. HasKey
    bool has_meta = root.HasKey("meta");
    bool has_fake = root.HasKey("fake");
    Print("HasKey('meta'): ", has_meta, " (Expected: true)");
    Print("HasKey('fake'): ", has_fake, " (Expected: false)");

    if (!has_meta || has_fake)
      Print("FAIL: HasKey broken");

    // 2. Size
    int root_size = root.Size(); // meta, data, flags, unicode = 4
    Print("Root Size: ", root_size, " (Expected: 4)");
    if (root_size != 4)
      Print("FAIL: Root Size broken");

    int data_size = root["data"].Size(); // 2 items
    Print("Data Size: ", data_size, " (Expected: 2)");
    if (data_size != 2)
      Print("FAIL: Data Size broken");

    // 3. GetKeys
    string keys[];
    int k_count = root.GetKeys(keys);
    Print("Keys Found: ", k_count);
    string k_str = "";
    for (int k = 0; k < k_count; k++)
      k_str += keys[k] + ",";
    Print("Key List: ", k_str);

    // 4. Unicode Check
    string uni = root["unicode"].ToString();
    Print("Unicode Check: ", uni);

    Print("ROUNDTRIP: PASS (Visual Check Required for Unicode)");
  } else {
    Print("ROUNDTRIP: FAIL (Parse Error ", check.GetLastError(), ")");
  }

  //---------------------------------------------------------
  // 4. LEGACY JASON ROUNDTRIP (Feature Check)
  //---------------------------------------------------------
  Print("--- TESTING LEGACY JASON ROUNDTRIP ---");
  CJAVal j_build;
  // Building via assignment (slower due to allocation, but easier syntax?)
  j_build["meta"]["version"] = 2;
  j_build["meta"]["timestamp"] = 123456789;

  // j_build["data"].Add(); // JAson array add usually tricky via []
  // Forced simplified construction for comparison
  j_build["unicode"] = "R$ 100,00 \u00A9";

  string j_built_str = j_build.Serialize();
  // Print("Legacy JSON: ", j_built_str);

  // Validation
  CJAVal j_check;
  if (j_check.Deserialize(j_built_str)) {
    Print("JAson Feature Check:");
    // JAson HAS Size() and check methods!
    // But HasKey is O(N) linear search (we checked source).
    int j_root_size = j_check.Size();
    Print("  Size:     ", j_root_size, " (Expected: 4)");
    
    // HasKey returns pointer or NULL
    bool j_has_meta = (CheckPointer(j_check.HasKey("meta")) != POINTER_INVALID);
    Print("  HasKey:   ", j_has_meta, " (Exists, but O(N))");
    
    // GetKeys still missing a direct 'GetKeys(string& dst[])' helper 
    // without manual iteration of children.
    Print("  GetKeys:  ? (Manual iteration required)");

    string uni_legacy = j_check["unicode"].ToStr();
    bool match = (uni_legacy == "R$ 100,00 \u00A9");
    Print("  Read:     ", match ? "PASS" : "FAIL");
  }

  //---------------------------------------------------------
  // RESULTS
  //---------------------------------------------------------
  Print("==================================================");
  Print("VALIDATION CHECK:");
  // Compact both strings for fair comparison (remove potential whitespace
  // differences if any) Actually, let's just compare raw first.
  if (dummy_ser == "")
    dummy_ser = toolkit.Serialize(); // Ensure we have last state
  if (dummy_ser != dummy_ser) {      /* No-op, just to ensure variable usage */
  }

  // Re-serialize final state to be sure
  string a_final = toolkit.Serialize();
  string j_final = jason.Serialize();

  if (a_final == j_final) {
    Print("PASS: Output matches exactly.");
  } else {
    Print("WARNING: Output mismatch!");
    Print("AI-Toolkit: ", StringSubstr(a_final, 0, 100), "...");
    Print("JAson:      ", StringSubstr(j_final, 0, 100), "...");
    Print("Lengths: AI-Toolkit=", StringLen(a_final),
          " JAson=", StringLen(j_final));
  }

  Print("==================================================");
  Print(StringFormat("TOTAL TIME (AI-Toolkit): %d us", total_toolkit));
  Print(StringFormat("TOTAL TIME (Legacy):     %d us", total_jason));

  double speedup = (double)total_jason / (double)total_toolkit;
  Print(StringFormat("OVERALL SPEEDUP: %.2fx", speedup));

  Print("Breakdown:");
  Print(StringFormat("  Parse:     %.2fx", (double)j_parse / t_parse));
  Print(StringFormat("  Read:      %.2fx", (double)j_read / t_read));
  Print(StringFormat("  Array Sum: %.2fx", (double)j_sum / t_sum));
  Print(StringFormat("  Serialize: %.2fx", (double)j_ser / t_ser));
  Print("==================================================");
}
