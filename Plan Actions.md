# Millionus Computer Use Harness — Plan → Actions

> Implementation has started. Current English implementation status, evidence, and unmet gates are maintained in [docs/STATUS.md](docs/STATUS.md). The original planning checklist below is not a claim of completed implementation.

## Current ownership and execution priority (2026-10-28)

Agent Ultra is delegated to another agent. Do not work in that checkout or extend its host adapter. The active harness-only sequence is defined in [remaining delivery plan](docs/HARNESS-REMAINING-PLAN.md): bounded stdio defect investigation; remaining native interruption acceptance; production broker/worker boundary; capture; supported provider matrix; signed distribution/hardware gates. Follow [acceptance queue](docs/ACCEPTANCE-NEXT.md) and keep actual evidence separate from planning.

## Worker implementation checkpoint (English, 2026-10-29)

H3 now has an internal cancellable read-worker lifecycle, reusable process owner and actual cooperative/uncooperative child termination evidence. Current Debug/Release suites each pass 249 cases / 2611 assertions. This is not a production helper, native AX-worker or permission-isolation pass; [implementation boundary](docs/read-worker-lifecycle.md) lists the next transport and platform work.

## Current implementation record (English, 2026-10-28)

P1/P4 now includes authenticated bounded XPC requests, revocable connection contexts and connection-owned core sessions. Eleven independent-process signing and lifecycle scenarios passed using development CDHash pins, including cancellation of an unapproved core session on client disconnect. The independently launched companion now passes approved lifecycle and one opt-in fixture AX action through the typed SDK. Separate native input opt-ins now pass four positive fixture routes and actual Stop/disconnect mouse-up cleanup. Stable identity and the full permission/interruption acceptance matrix remain open. See `docs/authenticated-ipc.md`.

P2 capture geometry now uses bounded uniform scaling, overflow-safe coordinate conversion and native post-capture identity/geometry checks, plus a monotonic result-admission deadline and shared unique-window revalidation. Synthetic verification and live acceptance are tracked separately in `docs/capture-geometry.md`.

P2 AX observation now uses a monotonic traversal budget, conservative start timestamps and transactional target publication. Partial observations cannot authorize native actions. See `docs/accessibility-observation.md`; live acceptance remains pending.

P3 execution now revalidates task cancellation and session generation after preflight and after durable intent, before entering effect callbacks. Known pre-dispatch refusals are journaled as not applied. Late completion verification is revalidated against the original session before journaling, without erasing a reported applied effect. See `docs/execution-admission.md`; native interruption acceptance remains open.

P1/P4 action-result consistency is shared across SDK, execution and journal boundaries, with matching JSON Schema rules. Contradictory verification cannot be persisted as completion or accepted by a mutation client. See `docs/action-result-validation.md`.

P4 SDK session opening now rejects concurrent opens before RPC and fences delayed open replies across cancellation/shutdown. Heartbeat ticks are bound to the exact ownership lifecycle across asynchronous replies. See `docs/sdk-session-lifecycle.md`; native lifecycle acceptance remains separate.

P2/P4 observation structure validation is shared by the execution engine and stdio SDK, including unique handles, geometry, action lists and aggregate UTF-8 limits. See `docs/observation-validation.md`; freshness and native authorization remain separate.

P1/P4 session metadata validation now rejects inconsistent pause reasons and malformed identifiers, generations or timestamps on every SDK session response. See `docs/session-validation.md`; native authorization and monotonic leases remain authoritative.

P4 agent orchestration now validates custom-adapter session/observation/result data itself, rejects incomplete or stale snapshots before planning, and requires a new observation ID after planning. See `docs/agent-adapter-boundary.md`; provider/native pilot gates remain open.

P4 provider adapters now share fixture-input admission before credential lookup and before HTTP submission. Direct calls reject malformed, incomplete, stale or ambiguous observations without egress. See `docs/provider-input-admission.md`; real inference acceptance remains separate.

P4 provider responses now use bounded duplicate-member JSON validation, including OpenAI’s nested proposal text. See `docs/provider-response-validation.md`; real provider/native acceptance remains separate.

P6 development packaging now has active-process refusal, tested cross-process locking, strict lock/destination admission, complete signed staging, failure recovery and full-workflow injected-failure regressions. A bounded, read-only recovery inventory and package consistency receipt with read-only verification are also available. This does not close production distribution gates. See `docs/development-packaging.md`.

P4 capability discovery is implemented: a shared typed response, optional SDK interface, schema, policy compatibility checks and gesture-test preflight. An opt-in negotiated SDK wrapper now enforces fresh feature/limit checks before mutation; cancellation remains independent of discovery. Image negotiation, authenticated IPC and live agent acceptance remain open. See `docs/capability-discovery.md`.

CU-018 now includes bounded gesture construction, an opt-in fixture, experimental vertical-scroll and fixed fixture-drag native routes, dedicated wire schemas, optional SDK capabilities and independent postcondition checks. Clean validation is recorded below. The basic two-action native fixture scroll/drag slice passed on 2026-10-27; the interruption matrix remains pending and no additional application is supported. A deterministic SDK acceptance runner, including target-role/geometry and negative-result checks, and explicit native-test CLI now verify both gestures with fresh observations and record success/failure evidence; the passing second native attempt is recorded in docs/STATUS.md. See `docs/gesture-execution.md`.


The detailed historical checklist below defines full acceptance, not individual code slices. Unchecked items must not be read as an absence of implementation; current partial work and evidence are tracked here and in `docs/STATUS.md`.

| Action area | Implemented increment | Acceptance state |
|---|---|---|
| CU-001–005 | Swift package, visible companion, TCC controls, AX/capture/input probes, development IPC ADR | Partial; production identity and peer authentication remain open |
| CU-006–022 | Typed actions and independently checked wire schemas, session/generation policy, heartbeat lease, pause reasons, persistent idempotency, input cleanup, semantic/native text/native click, fixture verification | Partial; full scenario/hardware/interruption matrix remains open |
| CU-023–026 | Swift SDK, MCP, agent loop, OpenAI Responses and Anthropic Messages planners, independent completion, budgets, no-progress detection | One-action native Anthropic and OpenAI slices passed; broader pilot acceptance remains open |
| CU-027–031 | Native coordinator and default-disabled Ultra preview wired; token-based selection suspension and drain; host regression suite 3296/0; isolated native pending-session Stop/close verified | Isolated approved action/Stop/close passed on 2026-10-27; normal-host lifecycle, production broker and full agent pilot pending |
| CU-032–036 | Threat model, private-state file admission and adversarial tests, verification scripts, ad-hoc packaging, notarization runbook, source/evidence hashes | Partial; distribution identity and release acceptance remain open |
| CU-037–042 | Expansion backlog retained | Deferred until core release gates pass |

Background validation: Latest Debug and optimized Release self-test suites pass 241 cases / 2555 assertions; independent wire-schema validation passes 59 checks. Earlier stdio inherited-output and mismatch/closed-input timeouts remain recorded as unresolved reliability findings. A bounded focused reproduction mode and payload-free stage diagnostics are available; see `docs/stdio-timeout-investigation.md`. The runner now rejects completion across a changed session generation and stops on unavailable effect verification. One user-approved native SDK fixture run has now passed with an 18-second synthetic planning delay, one action and independent completion verification. A real Anthropic one-action native fixture pilot passed on 2026-10-27; A one-action OpenAI native pilot also passed on 2026-10-27; the full agent acceptance matrix remains pending.

All new implementation and technical documentation is English. Detailed current commands and evidence are in the root README and `docs/evidence/README.md`.

Tarih: 24 Ekim 2026 · Sürüm: 0.1
Ana karar kaynağı: [plan.md](plan.md).

Bu belge uygulanacak işlerin sırasını, bağımlılığını, doğrulamasını ve teslim kanıtını tanımlar. Planlama incelemesi tamamlandı; aşağıdaki uygulama işleri henüz yapılmadı. Checkbox yalnızca ilgili kabul koşulu ve kanıt mevcut olduğunda işaretlenir.

## 1. Çalışma kuralları

1. Her iş için önce ilgili ana plan bölümü, dependency ve mevcut çalışma ağacı okunur.
2. Kaynak değişikliği küçük ve incelenebilir tutulur; mevcut kullanıcı değişiklikleri korunur.
3. Gerçek masaüstü testleri fixture/test klasöründe başlar. Kişisel mesaj, ödeme veya silme ile test yapılmaz.
4. Bir kapı geçmeden bağımlı faz tamamlanmış gösterilmez. Synthetic ve live kanıt ayrıdır.
5. Test hata verirse sebep kaydedilir; doğrulama azaltılarak başarı üretilmez.
6. Her işin sonunda durum, değişen dosyalar, test komutu, sonuç ve kalan risk kaydedilir.
7. Secret, ham clipboard veya kullanıcı ekranı kanıt dosyalarına varsayılan olarak eklenmez.
8. Model/SDK güncellemeleri capability ve sözleşme testiyle alınır; otomatik uyum varsayılmaz.
9. İmzalama ve sistem izinleri uygulama sırasında gerçek erişim gerektirir; yoklukları açık blocker olur.
10. Mimari değişirse önce ADR ve etkilenen plan/action maddeleri birlikte güncellenir.

Durumlar: `todo`, `in_progress`, `blocked`, `done`, `deferred`. `blocked` için neden ve açılma koşulu yazılır. Boyutlar: S dar iş; M birkaç bileşen; L kodlamadan önce alt işlere bölünecek iş. Bunlar gün tahmini değildir. Owner alanları rol belirtir; agent ataması veya fiilen paralel çalışma anlamına gelmez.

## 2. Tamamlanan planlama teslimatı

- [x] D00 — Boş harness çalışma klasörünü ve mevcut Agent Ultra proje yerini doğrula.
- [x] D01 — Paket, README, bridge, sandbox, selection, Ultra coordinator/handover ve UI mesaj sınırlarını incele.
- [x] D02 — macOS/MCP resmi kaynaklarına başvur; tam alınamayan kaynakları ve doğrulama boşluklarını kaydet.
- [x] D03 — Mimari, güvenlik, API, test, faz ve riskleri `plan.md` içinde yaz.
- [x] D04 — Bu bağımlı uygulama iş listesini oluştur.

D00–D04 ürünün çalıştığı anlamına gelmez. Bu teslimatta Agent Ultra kaynak kodu değiştirilmedi ve canlı inference/GUI kontrolü yapılmadı.

## 3. P0 — Teknik keşif ve karar kapısı G0

### CU-001 — Depo ve araç zinciri temeli
- [ ] Durum: todo · Owner: core · Boyut: S · Bağımlılık: D04.
- İş: Git durumu ve ignore kuralları; Swift package iskeleti; test komutları; Xcode/SDK ve minimum platform matrisi. Mevcut boş klasör için repo kurma kararı uygulanırken başka repo iç içe yaratılmadığı doğrulanır.
- Kabul: minimal package build/test çalışır; macOS 14 availability denetimi vardır; uygulama sırları veya build çıktıları sürüme girmez.
- Kanıt: `docs/evidence/CU-001/toolchain.md`, build/test sonuçları.

### CU-002 — TCC ve paket kimliği denemesi
- [ ] Durum: todo · Owner: macOS · Boyut: M · Bağımlılık: CU-001.
- İş: görünür minimal companion; Accessibility ve Screen Recording durum/istek akışı; imzalı uygulama ve helper kimliği deneyi. Input Monitoring gereksinimini ayrı ölç.
- Kabul: izin yok/var/iptal edilmiş durumları ayrılır; izin kendi kendine açılmaz; TCC'nin hangi executable'ı yetkilendirdiği kaydedilir; güncelleme kimliği için test planı vardır.
- Kanıt: `docs/adr/001-permission-identity.md`, temiz kullanıcı gözlemleri. Developer ID yoksa ad-hoc deneme ayrı etiketlenir, yayın kanıtı sayılmaz.

### CU-003 — AX, capture ve input dikey teknik denemesi
- [ ] Durum: todo · Owner: macOS · Boyut: M · Bağımlılık: CU-002.
- İş: izinli fixture penceresini yakala, bir AX öğesini oku, yerel düğmeye bas ve sonucu oku. Capture/AX timeout ve Stop'u dene.
- Kabul: doğru pencere kimliği; capture piksel/point dönüşümü ölçülmüş; UI donmuyor; izin çekilince yeni input yok.
- Kanıt: `docs/evidence/CU-003/spike.md`; yalnızca fixture görüntüleri.

### CU-004 — IPC ve güven sınırı ADR'si
- [ ] Durum: todo · Owner: security/core · Boyut: L · Bağımlılık: CU-002, CU-003.
- İş: XPC companion/SDK/CLI bağlantı prototipi; peer/code identity, sandbox'tan broker yolu, scope/grant taslağı; gerekirse Unix socket fallback karşılaştırması.
- Kabul: yetkisiz istemci ve sahte session reddedilir; yalnızca aynı UID'ye dayanılmaz; GUI yetkisi genel komut çalıştırmaya dönüşmez. Seçilen topoloji P0 kanıtına dayanır.
- Kanıt: `docs/adr/002-ipc-boundary.md`, `docs/security/threat-model.md`.

### CU-005 — Sürüm ve kapsam kararlarını kilitle
- [ ] Durum: todo · Owner: architecture · Boyut: S · Bağımlılık: CU-001…CU-004.
- İş: minimum macOS/SDK, TCC sahibi, IPC, ilk 20 fixture senaryosu ve ilk model adapter adayını karara bağla. Kesinleşmeyen dış bağımlılıkları kaydet.
- Kabul G0: teknik dikey dilim tekrarlanabilir; engeller ve destek matrisi açık; P1 için sözleşme kararları hazır.
- Kanıt: `docs/adr/003-v1-scope.md`, `docs/evidence/G0.md`.

## 4. P1 — Sözleşmeler, politika, oturum; G1

### CU-006 — Sürümlemeli veri sözleşmeleri
- [ ] Durum: todo · Owner: core · Boyut: M · Bağımlılık: CU-005.
- İş: Session, Observation, Target, Action union, Result, Capability, Grant ve Error; JSON schema + Swift Codable örnekleri.
- Kabul: round-trip ve Swift/schema tutarlılığı; bilinmeyen sürüm/action, bozuk enum, NaN/overflow, boyut/depth limitleri reddedilir.
- Kanıt: `Schemas/v1/`, `Tests/ContractsTests/`; geçerli ve geçersiz golden payload'lar.

### CU-007 — Session state machine ve tek yazıcı lease
- [ ] Durum: todo · Owner: core · Boyut: M · Bağımlılık: CU-006.
- İş: actor tabanlı oturum, generation, heartbeat/TTL, deadline, cancel, pause/resume ve restart-interrupted davranışı.
- Kabul: iki istemci aynı anda mutate edemez; eski generation çalışmaz; cancel sonrası geç sonuç session'ı diriltemez; expired lease yeni input üretemez.
- Kanıt: fake-clock concurrency testleri ve transition tablosu.

### CU-008 — Scope, grant ve politika motoru
- [ ] Durum: todo · Owner: security/core · Boyut: L · Bağımlılık: CU-006, CU-007.
- İş: app/window/action scope, native-origin grant, payload binding, expiry/revocation, hassas akış kuralları; keyfi shell/script kapsam dışı.
- Kabul: model/UI payload'u kendi kendine grant üretemez; değişmiş alıcı/içerik grant'i kullanamaz; kapsam içi rutin işlem tekrar onay istemez; bilinmeyen risk açık ret/devir olur.
- Kanıt: policy karar matrisi; spoof/replay/TOCTOU negative testleri.

### CU-009 — Intent journal ve idempotency
- [ ] Durum: todo · Owner: core · Boyut: M · Bağımlılık: CU-006, CU-007.
- İş: intent/result kaydı, payload hash, bounded retention, schema migration koruması, `effect_unknown` uzlaştırması.
- Kabul: aynı key aynı komut çift uygulanmaz; farklı payload conflict; intent sonrası crash tekrar mutasyon üretmez; disk full intent'i engellerse execute edilmez.
- Kanıt: crash-point test matrisi, bozuk/yeni sürüm veri fixture'ları.

### CU-010 — Sahte platform ve deterministik çekirdek kapısı
- [ ] Durum: todo · Owner: test/core · Boyut: M · Bağımlılık: CU-006…CU-009.
- İş: fake AX/capture/input/clock; injection payload'ları, time budget ve queue saturation senaryoları.
- Kabul G1: Core testleri gerçek masaüstüne erişmeden çalışır; güvenlik invariants geçer; her failed assertion anlamlı neden üretir.
- Kanıt: `docs/evidence/G1.md`, test sonuç özeti.

## 5. P2 — Gözlem motoru; G2

### CU-011 — Uygulama, pencere ve display envanteri
- [ ] Durum: todo · Owner: macOS · Boyut: M · Bağımlılık: CU-010.
- İş: app/PID/start identity, window identity, display layout version, aktivasyon öncesi görünürlük modeli.
- Kabul: kapanıp yeniden açılan app eski PID/handle ile karıştırılmaz; negatif display origin ve hot-plug tespit edilir.
- Kanıt: native fixture ve gerçek çoklu ekran sonuçları.

### CU-012 — Bounded AX snapshot ve hedef çözümleme
- [ ] Durum: todo · Owner: macOS · Boyut: L · Bağımlılık: CU-011.
- İş: traversal, role/action/value whitelist, secure-field exclusion, bounds, timeout, transient element registry.
- Kabul: derin/döngülü/yavaş ağaç UI'yı kilitlemez; duplicate label ambiguous olur; secure değer log/output'a girmez; truncation açık bildirilir.
- Kanıt: AX fixture suite, traversal süre/limit raporu.

### CU-013 — ScreenCaptureKit pipeline
- [ ] Durum: todo · Owner: macOS · Boyut: L · Bağımlılık: CU-011.
- İş: hedef pencere/display capture, crop/scale metadata, freshness, boş frame tespiti, cache limitleri ve kaynak kapatma.
- Kabul: izin yokken açık hata; kapatılan pencere eski frame ile yeni gözlem sayılmaz; ses yakalanmaz; capture stop kaynakları bırakır.
- Kanıt: capture lifecycle testleri ve memory ölçümü.

### CU-014 — Koordinat dönüşümü ve snapshot tutarlılığı
- [ ] Durum: todo · Owner: core/macOS · Boyut: M · Bağımlılık: CU-012, CU-013.
- İş: pixel/point/AppKit dönüşümleri, crop offset, rotation, AX-capture zaman farkı ve stale politikası.
- Kabul: round-trip property testleri; 1×/2× karışık ekran ve negatif origin; layout değişince eski target ret; AX ile capture ayrı timestamp taşır.
- Kanıt: dönüşüm golden set'i ve cihaz ölçümleri.

### CU-015 — Observe, artifact ve doctor yüzeyi
- [ ] Durum: todo · Owner: client · Boyut: M · Bağımlılık: CU-014, CU-008.
- İş: `doctor`, `capabilities`, `observe`; session-bound görüntü artifact referansları; redacted export.
- Kabul G2: read-only akış mutasyon yapmaz; artifact ID başka session'da açılamaz; keyfi path okunmaz; izin eksikleri kullanıcıya doğru anlatılır.
- Kanıt: `docs/evidence/G2.md`; read-only smoke sonuçları.

## 6. P3 — Eylem, doğrulama, insan kontrolü; G3

### CU-016 — Scheduler ve yürütme ön kontrolleri
- [ ] Durum: todo · Owner: core · Boyut: M · Bağımlılık: CU-015, CU-009.
- İş: serialized action queue; policy/lease/focus/freshness kontrolü; bounded backlog; intent-before-effect.
- Kabul: target değişirse input yok; expired deadline kuyrukta uygulanmaz; cancel normal işlerin önüne geçer.
- Kanıt: queue/focus/race fault testleri.

### CU-017 — AX semantik eylemler
- [ ] Durum: todo · Owner: macOS · Boyut: M · Bağımlılık: CU-016.
- İş: press, desteklenen value setter ve focused target davranışı; unsupported action hataları.
- Kabul: disabled/ambiguous/stale öğe mutate edilmez; işlemin gerçek sonucu fixture state'inden doğrulanır.
- Kanıt: native semantik action suite.

### CU-018 — Görsel fare ve scroll eylemleri
- [ ] Durum: todo · Owner: macOS · Boyut: M · Bağımlılık: CU-016, CU-014.
- İş: click/double-click, pointer move, scroll ve bounded drag; görünür pencere/occlusion kontrolü.
- Kabul: modal arkasına kör click yok; display çıkarılınca ret; cancel drag/button release dener; yanlış hedef toleransı sıfır.
- Kanıt: canvas fixture, modal ve ekran çıkarma testleri.

### CU-019 — Klavye ve Unicode metin
- [ ] Durum: todo · Owner: macOS · Boyut: M · Bağımlılık: CU-016.
- İş: chord/key event/text ayrımı, modifier state, güvenli chunking; clipboard fallback sonraki capability olarak kapalı.
- Kabul: Türkçe Q/F, emoji, IME/dead key; odak değişiminde yazma durur; cancel sonrası basılı modifier kalmaması test edilir; secure input kullanıcıya devredilir.
- Kanıt: input locale matrisi ve cleanup testleri.

### CU-020 — Verification ve güvenli recovery
- [ ] Durum: todo · Owner: core/macOS · Boyut: L · Bağımlılık: CU-017…CU-019.
- İş: element/value/window koşulları, event-driven wait, bounded retry, effect unknown uzlaştırması.
- Kabul: “olay gönderildi” başarı değildir; fake success metni doğrulama sayılmaz; applied/unknown action otomatik tekrar edilmez; time budget aşılmaz.
- Kanıt: timeout-before/after-effect, partial text ve duplicate-submit senaryoları.

### CU-021 — Native kontrol UI'sı ve kullanıcıya devir
- [ ] Durum: todo · Owner: UI/macOS · Boyut: M · Bağımlılık: CU-007, CU-008, CU-016.
- İş: aktif session/scope, Pause/Resume/Stop, native grant, kullanıcı müdahalesi, lock/sleep/disconnect davranışı.
- Kabul: Stop model cevabı beklemez; global kısayol çalışmasa native Stop vardır; fiziksel input'ta pause; uyandıktan sonra otomatik input yok; grant onayı agent tarafından taklit edilemez.
- Kanıt: fiziksel input test tutanağı; Stop gecikme dağılımı.

### CU-022 — Motor kabul paketi
- [ ] Durum: todo · Owner: test · Boyut: L · Bağımlılık: CU-020, CU-021.
- İş: 20 senaryo × 10 tekrar; kill/crash/TCC revoke/disk full/AX hang/çoklu client testleri.
- Kabul G3: ana plan §14 eşikleri; güvenlik ihlali sıfır; beklenmeyen retler ayrı başarısızlık; tekrar üretilebilir sonuç kaydı.
- Kanıt: `docs/evidence/G3.md`, makine okunur sonuçlar; fixture dışı kapsam açık.

## 7. P4 — SDK, MCP ve ilk model; G4

### CU-023 — Swift SDK ve CLI ürünleştirmesi
- [ ] Durum: todo · Owner: client · Boyut: M · Bağımlılık: CU-022, CU-004.
- İş: typed async SDK, session event stream, cancel/deadline, structured CLI output, IPC auth ve capability negotiation.
- Kabul: CLI stdout makine formatına uygun; log stderr; disconnect yeni input'u durdurur; reconnect unknown action'ı tekrarlamaz.
- Kanıt: client/broker integration testleri ve örnek istemci.

### CU-024 — MCP stdio adapter
- [ ] Durum: todo · Owner: protocol · Boyut: M · Bağımlılık: CU-023.
- İş: initialization/version negotiation, tools/list-call, cancellation, bounded message framing, image content ve hata mapping. Uygun SDK değerlendirilir; sürüm pinlenir.
- Kabul: gerçek bağımsız MCP istemciyle round-trip; stdout yalnız protokol; aşırı/geçersiz mesaj ret; tool availability gerçek capability'ye bağlı; adapter native grant yaratamaz.
- Kanıt: protokol conformance senaryoları ve negotiated sürüm kaydı. JSON-RPC uygulamak tek başına MCP uyumluluğu sayılmaz.

### CU-025 — Provider/model capability matrisi
- [ ] Durum: todo · Owner: integration · Boyut: M · Bağımlılık: CU-024.
- İş: görüntü, structured output, tool response, timeout/cancel, model identity ve sandbox erişimi için aday adapter denemesi.
- Kabul: ilk pilot adapter gerçek çalıştırmayla doğrulanır; desteklenmeyen sağlayıcıya sessiz fallback yok; kullanıcı credential'ı harness'a kopyalanmaz.
- Kanıt: `docs/provider-matrix.md`; startup ve gerçek inference kanıtları ayrı.

### CU-026 — Agent loop ve görev bütçeleri
- [ ] Durum: todo · Owner: integration/core · Boyut: M · Bağımlılık: CU-025.
- İş: observe/propose/policy/execute/verify loop; adım/süre/tekrar bütçesi; model gecikmesinde pause ve session continuity.
- Kabul: model çıktı parse hatası input üretmez; prompt injection policy değiştiremez; aynı başarısız durumda sonsuz döngü yok; unknown effect yeniden submit edilmez.
- Kanıt: adversarial fixture görevleri ve loop trace.

### CU-027 — Gerçek agent pilotu
- [ ] Durum: todo · Owner: test/integration · Boyut: M · Bağımlılık: CU-026.
- İş: 10 sabit görev × 5 tekrar; gerçek model, fixture ve seçili yerel uygulamalar; bağımsız final-state scorer.
- Kabul G4: %90 doğrulanmış tamamlama; safety sıfır tolerans; model/harness/user hata dağılımı; maliyet veya kota kullanımı açık.
- Kanıt: `docs/evidence/G4.md`; provider/model/CLI sürümleri, request sayıları, latency ve sonuçlar.

## 8. P5 — Agent Ultra entegrasyonu; G5

### CU-028 — Ultra adapter ve ayrı coordinator
- [ ] Durum: todo · Owner: integration · Boyut: L · Bağımlılık: CU-027.
- İş: ayrı `ComputerUseSessionCoordinator`, `ComputerUseClient`, explicit feature gate ve stop lifecycle. Entegrasyondan önce Ultra çalışma ağacı yeniden incelenir; inceleme tarihi baseline sayılmaz.
- Kabul: Code/Ask/Plan/plain chat semantiği değişmez; mevcut gizli Ultra açılmaz; geç round sonuçları durdurulmuş harness'ı canlandıramaz.
- Kanıt: `Integrations/AgentUltra/README.md`, dar entegrasyon diff'i ve lifecycle testleri.

### CU-029 — UI olayları ve native yetki akışı
- [ ] Durum: todo · Owner: UI/integration · Boyut: M · Bağımlılık: CU-028, CU-021.
- İş: ChatSink/activity adaptasyonu; scope/aktif app/action/result görünümü; native grant; pause/stop; SelectionMonitor yarışma yönetimi.
- Kabul: WebView token/onay yetkisi edinmez; başka chat'in action'ı görünmez; notch Stop doğru session'a gider; selection fallback agent input'una müdahale etmez.
- Kanıt: multi-chat integration ve gerçek native UI gözlemi.

### CU-030 — CLI sandbox/broker sınırı
- [ ] Durum: todo · Owner: security/integration · Boyut: L · Bağımlılık: CU-028, CU-024.
- İş: seçili provider'a dar broker kanalı; yönetilen geçici config; mevcut AppleEvent/LaunchServices/genel shell kısıtlarını koru.
- Kabul: yetkisiz CLI/eskimiş oturum broker üzerinden yazamaz; normal Code agent computer-use yetkisi edinmez; global kullanıcı MCP ayarları değişmez; profil dışı mutasyon testleri reddedilir.
- Kanıt: positive + negative sandbox testleri. Yalnız negative test, child'ın gerçekten başladığını kanıtlamaz.

### CU-031 — Ultra regresyon ve gerçek entegrasyon görevi
- [ ] Durum: todo · Owner: test/integration · Boyut: L · Bağımlılık: CU-029, CU-030.
- İş: mevcut Swift selftest ve extension testlerini baseline ile karşılaştır; gerçek computer-use görevinde observe/action/verify/Stop zinciri.
- Kabul G5: eski sohbet/proposal/hesap davranışlarında regresyon yok; public build'de mevcut Ultra beta politikası korunur; gerçek bilgisayar eylemi doğrulanır.
- Kanıt: `docs/evidence/G5.md`; mevcut test komutları ilgili proje README'sinden çalıştırma anında doğrulanır.

## 9. P6 — Üretim sertleştirme ve yayın; G6

### CU-032 — Mahremiyet ve adversarial doğrulama
- [ ] Durum: todo · Owner: security · Boyut: L · Bağımlılık: CU-031.
- İş: ekran/AX injection corpus, grant replay, unauthorized peer, artifact traversal, redaction/export, retention ve cross-session leak denemeleri.
- Kabul: secret fixture değerleri log/export'ta yok; scope genişletme ret; bilinmeyen hassas frame egress yok; residual risk açık yazılı.
- Kanıt: `docs/security/review.md`, regression corpus ve kapatılmamış bulgu listesi.

### CU-033 — Performans ve uzun oturum
- [ ] Durum: todo · Owner: macOS/test · Boyut: M · Bağımlılık: CU-031.
- İş: capture/AX/input/verify/Stop timing, CPU/RSS, queue pressure; iki saat fixture soak ve tekrar capture start/stop.
- Kabul: plan hedefleri ölçülür; kaynak sızıntısı veya session drift yok; hedef kaçırılıyorsa release kararı gerekçeli, güvenlik kapıları gevşetilmez.
- Kanıt: `Benchmarks/` sonuçları ve `docs/evidence/performance.md`.

### CU-034 — İmzalama, paketleme ve notarization
- [ ] Durum: todo · Owner: release · Boyut: L · Bağımlılık: CU-032, CU-033.
- İş: sabit bundle ID, minimum entitlement, hardened runtime, Developer ID, notarization ve staple/check zinciri; dependency/license envanteri.
- Kabul: temiz kullanıcıda uygulama açılır; doğru bileşen TCC listesinde; signature doğrulanır; imzalama sırrı depoya/log'a girmez. Credential yoksa blocked, ad-hoc başarıyla done yapılmaz.
- Kanıt: sanitized paket manifesti, signature/notary sonucu ve binary hash.

### CU-035 — Upgrade, kurtarma ve kaldırma
- [ ] Durum: todo · Owner: release/core · Boyut: M · Bağımlılık: CU-034.
- İş: eski/yeni schema davranışı, aktif session sırasında update, bozuk journal, app kaldırma, kalan izin/veri açıklaması.
- Kabul: update önce çalışmayı durdurur; relaunch eski action replay etmez; ileri şema overwrite edilmez; uninstall kullanıcının başka verisini silmez.
- Kanıt: fresh-install/upgrade/recovery/uninstall matrisi.

### CU-036 — Kullanım belgeleri ve release kararı
- [ ] Durum: todo · Owner: release · Boyut: M · Bağımlılık: CU-035.
- İş: kurulum/izin, ilk görev, SDK/MCP, Stop/kurtarma, desteklenen app/OS/model, bilinen sınırlamalar; release checklist ve rollback runbook.
- Kabul G6: G0–G5 ve güvenlik bulguları gözden geçirilmiş; destek beyanı gerçek test matrisiyle eşleşiyor; açık kritik bulgu yok; paket yeniden üretilebilir.
- Kanıt: `docs/evidence/G6.md`, release manifesti ve son kabul tutanağı. Yayın kanalı/hesabı gerektiren adım ayrıca somut paket üzerinden yürütülür.

## 10. P7 — İlk sürüm sonrası kontrollü genişleme

Bunlar v1 kapısını geciktirmeyen backlog'dur; her biri capability ve ayrı kabul paketi gerektirir.

- [ ] CU-037 — Yerel Vision OCR, güven skorları ve canvas hedefleme; bağımlılık CU-036; boyut M. Kabul: OCR kutusu gerçek AX öğesi gibi sunulmaz; düşük güven devir/ret.
- [ ] CU-038 — Chromium/Safari DOM adapter fizibilitesi; bağımlılık CU-036; boyut L. Kabul: açık tab origin/scope, bağlantı kimliği, browser debugging portunu genel ağa açmama; gerçek browser testi.
- [ ] CU-039 — Opt-in clipboard ve gelişmiş drag/file dialog; bağımlılık CU-036; boyut M. Kabul: concurrent clipboard değişikliği korunur; dosya diyaloglarında hedef yolu ve scope doğrulanır.
- [ ] CU-040 — Ek provider/model/app matrisi; bağımlılık CU-036; boyut L. Kabul: her adapter G4 benzeri kendi sonuçlarını üretir; bir modelin başarısı diğerine aktarılmaz.
- [ ] CU-041 — Intel ve diğer işletim sistemleri fizibilitesi; bağımlılık CU-036; boyut L. Kabul: gerçek donanım/OS spike; macOS güvenlik varsayımları başka platforma kopyalanmaz.
- [ ] CU-042 — Uzaktan kontrol transport araştırması; bağımlılık CU-036; boyut L. Kabul: ayrı tehdit modeli, auth/pairing/TLS/audit tasarımı; v1 stdio portu internete açılmaz.

## 11. İlk dikey dilim: tam olarak ne çalışacak?

İlk demonstrasyon bağımsız test uygulamasında olur:

1. Kullanıcı companion'ı açar, izin durumunu görür ve fixture uygulamasıyla sınırlı oturum başlatır.
2. Agent/CLI observation alır; hedef text alanını mevcut snapshot'tan belirler.
3. Harness scope, lease, target ve odağı kontrol eder; “Merhaba Milyonus” metnini girer.
4. Yerel “Save” fixture düğmesine basar. Bu düğme dış dünyaya mesaj göndermez.
5. Verification fixture'daki saved state'i doğrular; yalnızca sonra `verified` döner.
6. Aynı idempotency key ile tekrar talep ikinci metin veya ikinci kayıt üretmez.
7. Kullanıcı klavyeye dokunduğunda agent duraklar; Stop yeni input'u keser.
8. Pencere kapanır veya izin çekilirse açık hata döner; sistem başka pencereye yazmaz.

CU-003 bu akışın minimal teknik denemesidir; CU-022 güvenilir motor kabulü, CU-027 gerçek LLM kabulüdür. Bu ayrım “demo çalıştı, ürün hazır” sonucunu önler.

## 12. Başlangıç fixture senaryo listesi

| No | Senaryo | Beklenen kanıt |
|---|---|---|
| 01 | App/window envanteri | Doğru süreç ve pencere kimliği |
| 02 | AX button press | Fixture counter tam bir artış |
| 03 | Metin alanı | Beklenen Unicode değer |
| 04 | Türkçe/emoji/IME | Kayıp veya fazladan karakter yok |
| 05 | Scroll | Doğru container ve görünür öğe |
| 06 | Canvas click | Doğru koordinat hit-test sonucu |
| 07 | Modal overlay | Arka pencereye mutasyon yok |
| 08 | Disabled target | Açık ret ve sıfır etki |
| 09 | Aynı etiketli öğeler | Ambiguous ret |
| 10 | Stale observation | Yeni gözlem talebi |
| 11 | Focus değişimi | Yanlış alana input yok |
| 12 | Retina/crop | Beklenen point/pixel eşleşmesi |
| 13 | Çoklu ekran/hot-plug | Eski layout ret |
| 14 | TCC yok/revoke | Permission hatası, sıfır yeni input |
| 15 | Fiziksel kullanıcı müdahalesi | Pause + generation koruması |
| 16 | Stop sırasında key/drag | Yeni dispatch yok; cleanup sonucu |
| 17 | İki istemci | Tek writer ve diğerine lease-busy |
| 18 | Crash/disconnect sonrası belirsizlik | Unknown effect; kör retry yok |
| 19 | Prompt injection / sahte grant | Policy/scope değişmiyor |
| 20 | Secure alan / artifact izolasyonu | Secret export yok, cross-session ret |

Bu liste minimum settir; disk full, AX hang, lock/sleep ve upgrade ayrıca fault/release paketlerinde yer alır. Test sayılarını artırmak tek başına kalite kanıtı değildir; kullanıcıya zarar verebilecek sınırları kapsamak esastır.

## 13. İzlenebilirlik

| Ana plan alanı | İşler | Kapı |
|---|---|---|
| §1–5 kapsam/mimari/inceleme | CU-001–005 | G0 |
| §8 sözleşme | CU-006, 023–024 | G1/G4 |
| §6–7 gözlem/koordinat | CU-011–015 | G2 |
| §9 execution/recovery | CU-009, 016–020 | G3 |
| §10 session/insan kontrolü | CU-007, 021–022 | G3 |
| §11 yetki/tehdit | CU-004, 008, 030, 032 | G1/G5/G6 |
| §12 veri/mahremiyet | CU-009, 012–015, 032, 035 | G2/G6 |
| §13 Ultra/model | CU-025–031 | G4/G5 |
| §14 test/performans | CU-010, 022, 027, 031–036 | G1–G6 |
| §15–16 roadmap/risk | CU-005, 036–042 | G0/G6/P7 |

## 14. İş ve kanıt kayıt şablonu

Her iş tamamlandığında şu kayıt tutulur:

```yaml
id: CU-000
status: todo
owner: unassigned
started_at: null
completed_at: null
source_revision: null
working_tree_notes: null
os_version: null
architecture: null
app_signature: null
provider_model_version: null
changed_files: []
commands_run: []
expected_result: null
actual_result: null
evidence_paths: []
remaining_risks: []
blocker_and_exit_condition: null
```

CI log'u, fixture sonucu ve gerçek kullanıcı oturumu kanıtı ayrı etiketlenir. Bir dosyanın varlığı testin geçtiği anlamına gelmez. Gate kaydı; toplam/başarılı/başarısız/beklenen ret/beklenmeyen ret/atlanmış sayılarını ve tekrar üretme yolunu içerir. Test edilmemiş platform `untested` olarak görünür.

## 15. Sonraki uygulanacak adım

CU-001 ile paket ve test iskeletini kurmak; ardından CU-002–CU-004 ile TCC, native API ve IPC belirsizliklerini küçük bir çalışan dilimde çözmek. Bu belirsizlikler kapanmadan bütün provider'ları, geniş UI'yı veya tarayıcı adapter'larını aynı anda geliştirmek planın kritik yoluna katkı sağlamaz.


### P6 completion integrity increment — 2026-10-25

Implemented intent/method-bound immutable journal completion and response correlation checks, with engine pause on invalid completion. Six new deterministic regressions passed in Debug and Release (103 cases / 602 assertions total). This supplies partial recovery evidence for CU-035; its installation, upgrade and uninstall matrix and G6 remain open. See docs/STATUS.md and the self-test logs for evidence scope.


### P6 persistence failure containment — 2026-10-25

Ledger writes now fail closed after a persistence error until storage is reopened and revalidated. Intent-write failures pause the session before dispatch. Recovery matrix and four additional regressions are recorded in docs/evidence/journal-recovery.md. Debug and Release: 107 cases / 632 assertions, zero failures. Production crash/durability, upgrade and distribution gates remain open.


### P6 durability-boundary fault injection — 2026-10-25

Package-only checkpoints now exercise failures before file fsync, rename and directory fsync through the real journal writer. Four new test cases validate both persisted-state outcomes and engine pause/no-replay behavior. Debug and Release: 111 cases / 708 assertions, zero failures. See docs/evidence/journal-recovery.md; injected exceptions do not complete crash, power-loss or production release acceptance.


### P6 abrupt subprocess termination recovery — 2026-10-25

Added SIGKILL matrices for intent/completion at all three write boundaries, including kernel lease release and orphan temporary-record handling. Debug and Release: 113 cases / 761 assertions, zero failures; six isolated child terminations per configuration. Evidence is scoped to local self-test subprocesses, not native companion or power-loss acceptance. See docs/evidence/journal-recovery.md.


### P6 journal admission and capacity — 2026-10-25

Validated persisted identifier/fingerprint shape and incoming action contracts. Five regression cases cover malformed records, duplicate/excess entries, file-size refusal, exact-capacity completion and invalid new records. Debug and Release: 118 cases / 822 assertions, zero failures. Retention/rollover remains open; no automatic eviction or journal deletion was introduced.


### P6 client reply boundary — 2026-10-25

Added reply-envelope validation before request correlation, immediate malformed/oversized transport shutdown, interrupted-read handling and initialize cleanup. Five new cases include synthetic children over real pipes. Debug and Release: 123 cases / 878 assertions, zero failures. See docs/evidence/client-transport.md; native companion and production peer authentication acceptance are separate.


### P6 local tool-result validation — 2026-10-25

Added strict single-text-content validation, boolean error-flag admission and transport closure on malformed typed payloads while preserving valid domain refusals. Four new cases include real-pipe synthetic-child tests. Debug and Release: 127 cases / 917 assertions, zero failures. Production transport/security gates remain separate.


### P6 SDK action-result correlation — 2026-10-25

All mutation methods now bind returned request IDs to the submitted action and reject malformed action IDs by closing the transport. Two synthetic-child pipe matrices cover all three routes and preserve unknown-effect semantics. Debug and Release: 129 cases / 971 assertions, zero failures. Native verification and outstanding transport/security gates remain separate.


### P6 SDK session and observation correlation — 2026-10-25

Added response binding for open/status/heartbeat/cancel/observe, preserving expired cancellation and pre-session null status. Two synthetic-child pipe matrices cover nineteen invalid responses and valid lifecycle controls. Debug and Release: 131 cases / 1016 assertions, zero failures. Native authority and production authentication gates remain separate.


### P6 SDK cancellation and late replies — 2026-10-25

Added pre-dispatch and post-reply cancellation fencing, plus explicit late-reply refusal on closed transports. Four synthetic-child pipe tests cover non-dispatch, sibling cancellation, repeated shutdown and a confirmed delayed reply. Debug and Release: 135 cases / 1028 assertions, zero failures. Native interruption and indefinitely hostile child teardown remain open.


### P6 owned-child termination fallback — 2026-10-25

Added a one-second SIGTERM grace period followed by SIGKILL only for the SDK's still-running direct child. Three synthetic-child tests cover shutdown, cancellation and cooperative exit. Debug and Release: 138 cases / 1035 assertions, zero failures. Native forced-exit cleanup and descendant-process behavior remain separate acceptance work.


### P6 nonblocking transport, resource lifecycle and JSON admission — 2026-10-25

Implemented a bounded nonblocking write queue, cancellation-aware reader, per-descriptor SIGPIPE suppression, deadline enforcement and timeout-task cleanup. Added duplicate-member/depth/UTF-8 validation shared by SDK responses and companion request admission. Fourteen new cases cover real-pipe backpressure/resource behavior and JSON boundaries; existing pipe matrices include duplicate fields.

Clean Debug and Release: 156 cases / 1329 assertions, zero failures; independent schema validation: 25 passed. Retained failed fixture expectations and their fixes are documented in docs/evidence/client-transport.md. Consolidated review: docs/security/review.md. Live companion acceptance for the latest parser and all remaining native/distribution gates remain open; no packaging or GUI launch occurred.
