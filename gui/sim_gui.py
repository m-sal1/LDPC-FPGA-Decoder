# sim_gui.py
# GUI for configuring and running LDPC BER/FER and QKD simulations.
# Moustafa Salman

import sys, math, threading
from pathlib import Path
import numpy as np

import sys as _sys
if getattr(_sys, 'frozen', False):
    PROJECT_ROOT = Path(_sys._MEIPASS)
else:
    PROJECT_ROOT = Path(__file__).resolve().parents[1]

sys.path.insert(0, str(PROJECT_ROOT))

from PySide6.QtCore import Qt, QObject, QThread, Signal, Slot
from PySide6.QtGui import QColor, QFont
from PySide6.QtWidgets import (
    QApplication, QAbstractItemView, QComboBox, QFileDialog,
    QFrame, QGridLayout, QHBoxLayout, QHeaderView, QLabel,
    QLineEdit, QMainWindow, QMessageBox, QPushButton, QProgressBar,
    QSizePolicy, QStackedWidget, QStatusBar, QTableWidget,
    QTableWidgetItem, QTextEdit, QVBoxLayout, QWidget,
)


MATRICES = {
    "CCSDS n512  ·  irregular / serial":
        "matrices/CCSDS_ldpc_n512_k256.alist",
    "QC-LDPC irregular n512 z8  ·  parallel":
        "matrices/QC_LDPC_n512_k256_z8_irreg.alist",
}


QSS = """
* { font-family: "Segoe UI"; font-size: 10pt; }

QMainWindow, QDialog { background: #0d1117; }

QWidget { background: transparent; color: #e6edf3; }

QFrame#panel {
    background: #161b22;
    border: 1px solid #30363d;
    border-radius: 8px;
}

QPushButton {
    background: #21262d;
    color: #e6edf3;
    border: 1px solid #30363d;
    border-radius: 6px;
    padding: 6px 14px;
}
QPushButton:hover { background: #30363d; }
QPushButton:pressed { background: #0d1117; }
QPushButton:disabled { color: #484f58; border-color: #21262d; }

QPushButton#primary {
    background: #238636;
    color: white;
    border: 1px solid #2ea043;
    padding: 7px 18px;
    font-weight: 600;
}
QPushButton#primary:hover { background: #2ea043; }
QPushButton#primary:disabled { background: #1c2128; color: #484f58; border-color: #21262d; }

QPushButton#danger {
    background: #21262d;
    color: #f85149;
    border: 1px solid #30363d;
}
QPushButton#danger:hover { background: #3d1f1f; border-color: #f85149; }
QPushButton#danger:disabled { color: #484f58; }

QPushButton#mode {
    background: #21262d;
    color: #8b949e;
    border: 1px solid #30363d;
    border-radius: 6px;
    padding: 6px 16px;
}
QPushButton#mode:checked {
    background: #1f6feb;
    color: white;
    border-color: #1f6feb;
}

QComboBox {
    background: #161b22;
    color: #e6edf3;
    border: 1px solid #30363d;
    border-radius: 6px;
    padding: 6px 10px;
}
QComboBox:hover { border-color: #58a6ff; }
QComboBox QAbstractItemView {
    background: #161b22;
    color: #e6edf3;
    border: 1px solid #30363d;
    selection-background-color: #1f6feb;
}

QLineEdit {
    background: #0d1117;
    color: #e6edf3;
    border: 1px solid #30363d;
    border-radius: 6px;
    padding: 5px 8px;
}
QLineEdit:focus { border-color: #58a6ff; }

QTableWidget {
    background: #0d1117;
    alternate-background-color: #161b22;
    color: #e6edf3;
    border: none;
    gridline-color: #21262d;
    font-family: "Cascadia Mono", "Consolas", monospace;
    font-size: 9.5pt;
}
QHeaderView::section {
    background: #161b22;
    color: #8b949e;
    border: none;
    border-bottom: 1px solid #30363d;
    padding: 8px 6px;
    font-size: 8pt;
    font-weight: 700;
    text-transform: uppercase;
}

QTextEdit {
    background: #0d1117;
    color: #8b949e;
    border: none;
    font-family: "Cascadia Mono", "Consolas", monospace;
    font-size: 9pt;
}

QProgressBar {
    background: #21262d;
    border: none;
    border-radius: 3px;
    height: 6px;
}
QProgressBar::chunk { background: #238636; border-radius: 3px; }

QScrollBar:vertical {
    background: #0d1117;
    width: 8px;
    margin: 0;
}
QScrollBar::handle:vertical {
    background: #30363d;
    min-height: 20px;
    border-radius: 4px;
}
QScrollBar::handle:vertical:hover { background: #484f58; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }

QStatusBar { background: #161b22; color: #8b949e; border-top: 1px solid #21262d; }

QLabel { background: transparent; }
"""


class Worker(QObject):
    log        = Signal(str, str)
    progress   = Signal(float, str)
    ber_result = Signal(object)
    qkd_result = Signal(object)
    finished   = Signal()
    failed     = Signal(str)

    def __init__(self, mode, path, params, qkd_params, stop):
        super().__init__()
        self.mode, self.path = mode, path
        self.params, self.qkd_params, self.stop = params, qkd_params, stop

    @Slot()
    def run(self):
        try:
            if self.mode == "BER/FER": self._ber()
            else:                       self._qkd()
        except Exception:
            import traceback
            self.failed.emit(traceback.format_exc())
        finally:
            self.finished.emit()

    def _stopped(self): return self.stop.is_set()

    def _ber(self):
        from model.ldpc.h_matrix     import load_alist
        from model.ldpc.channel      import awgn_channel
        from model.ldpc.llr          import compute_llr_awgn
        from model.ldpc.quantization import quantize_llr
        from model.ldpc.decoder      import ldpc_decode

        g = self.params
        snr_min    = float(g["snr_min"])
        snr_max    = float(g["snr_max"])
        snr_steps  = int(g["snr_steps"])
        max_iter   = int(g["max_iter"])
        target_fe  = int(g["target_fe"])
        max_trials = int(g["max_trials"])
        attn       = float(g["attn"])

        H, chk, var = load_alist(str(self.path))
        N = H.shape[1]
        self.log.emit(f"  {self.path.name}   {H.shape[0]}×{N}   rate {(N-H.shape[0])/N:.2f}", "sub")

        snrs = np.linspace(snr_min, snr_max, snr_steps)
        bits = np.zeros(N, dtype=int)

        for i, snr in enumerate(snrs):
            if self._stopped(): break
            self.progress.emit(i/len(snrs)*95, f"Eb/N0 = {snr:.2f} dB")
            be = fe = ti = tr = 0
            for _ in range(max_trials):
                if self._stopped(): break
                tr += 1
                y, sig  = awgn_channel(bits, snr, 0.5)
                llr     = compute_llr_awgn(y, sig)
                llr_q   = quantize_llr(llr, 8, 2)
                dec, it = ldpc_decode(llr_q, H, chk, var, max_iter)
                e = int(np.sum(bits != dec))
                if e: fe += 1
                be += e; ti += it
                if fe >= target_fe: break

            ber = be / (tr * N) if tr else 0.0
            fer = fe / tr        if tr else 0.0
            avg = ti / tr        if tr else 0.0
            self.ber_result.emit({"snr": snr, "ber": ber, "fer": fer,
                                  "avg": avg, "trials": tr,
                                  "ber_floor": ber == 0, "fer_floor": fer == 0,
                                  "N": N})
            ber_s = f"<{1/(tr*N):.2e}" if ber == 0 else f"{ber:.3e}"
            fer_s = f"<{1/tr:.2e}"     if fer == 0 else f"{fer:.4f}"
            tag   = "good" if fer == 0 else ("warn" if fer < 0.3 else "bad")
            self.log.emit(f"  {snr:5.2f} dB    BER {ber_s:>10}    "
                          f"FER {fer_s:>10}    iter {avg:5.1f}    n={tr}", tag)

        self.progress.emit(100, "Done")
        self.log.emit("  Complete.", "good")

    def _qkd(self):
        from model.ldpc.h_matrix import load_alist
        from model.ldpc.decoder  import ldpc_decode

        g = self.qkd_params
        qber_min   = float(g["qber_min"])
        qber_max   = float(g["qber_max"])
        qber_steps = int(g["qber_steps"])
        trials     = int(g["qkd_trials"])
        max_iter   = int(g["qkd_iter"])
        hw_mbps    = float(g["hw_mbps"])

        def h(p):
            p = np.clip(p, 1e-10, 1-1e-10)
            return float(-p*math.log2(p) - (1-p)*math.log2(1-p))

        H, chk, var = load_alist(str(self.path))
        N = H.shape[1]; R = (N - H.shape[0]) / N
        self.log.emit(f"  {self.path.name}   {H.shape[0]}×{N}   rate {R:.2f}", "sub")

        rng = np.random.default_rng(42)
        for i, qber in enumerate(np.linspace(qber_min, qber_max, qber_steps)):
            if self._stopped(): break
            self.progress.emit(i/qber_steps*95, f"QBER = {qber:.3f}")
            ok = 0; krs = []
            q  = float(np.clip(qber, 1e-6, 1-1e-6))
            lm = math.log((1-q)/q)
            for _ in range(trials):
                if self._stopped(): break
                a   = rng.integers(0, 2, N)
                b   = a ^ (rng.random(N) < q).astype(int)
                llr = lm * (1 - 2*(b^a).astype(float))
                lq  = np.clip(np.round(llr*2), -127, 127).astype(float)/2
                dec, _ = ldpc_decode(lq, H, chk, var, max_iter)
                if not int(np.sum(a^dec != a)):
                    ok += 1
                    hq = h(qber)
                    f  = (1-R)/hq if hq > 0 else 999
                    krs.append(max(0., 1-(1+f)*hq))
            fer  = 1 - ok/trials if trials else 1.
            fv   = (1-R)/h(qber)
            kr   = float(np.mean(krs)) if krs else 0.
            skr  = kr * hw_mbps
            sec  = kr > 0
            self.qkd_result.emit({"qber": qber, "fer": fer, "kr": kr,
                                  "f": fv, "skr": skr, "secure": sec})
            tag = "good" if sec and fer < 0.1 else ("warn" if sec else "bad")
            self.log.emit(f"  {qber:.3f}    FER {fer:.3f}    "
                          f"key {kr:.4f}    f {fv:.2f}    "
                          f"SKR {skr:.3f} Mbps    {'SECURE' if sec else 'NO KEY'}", tag)

        self.progress.emit(100, "Done")
        self.log.emit(f"  SKR uses hw throughput {hw_mbps} Mbps.", "sub")
        self.log.emit("  Complete.", "good")


class Reconciler(QMainWindow):
    def __init__(self):
        super().__init__()
        self.worker_thread = self.worker = self.stop_event = None
        self.running = False
        self.setWindowTitle("Reconciler")
        self.setMinimumSize(1080, 680)
        self._build()
        self._set_mode("BER/FER")

    def _panel(self):
        f = QFrame(); f.setObjectName("panel")
        return f

    def _build(self):
        root = QWidget(); self.setCentralWidget(root)
        main = QVBoxLayout(root)
        main.setContentsMargins(16, 14, 16, 12)
        main.setSpacing(10)

        top = QHBoxLayout()

        title = QLabel("Reconciler")
        title.setStyleSheet("font-size:14pt; font-weight:700; color:#e6edf3;")
        top.addWidget(title)
        top.addStretch()

        self.status_lbl = QLabel("READY")
        self.status_lbl.setStyleSheet("color:#3fb950; font-weight:700; font-size:9pt;")
        top.addWidget(self.status_lbl)
        top.addSpacing(16)

        self.stop_btn = QPushButton("Stop")
        self.stop_btn.setObjectName("danger")
        self.stop_btn.clicked.connect(self._stop)
        self.stop_btn.setEnabled(False)
        top.addWidget(self.stop_btn)

        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self._save)
        top.addWidget(save_btn)

        main.addLayout(top)

        cfg = self._panel()
        ch  = QHBoxLayout(cfg); ch.setContentsMargins(12, 10, 12, 10); ch.setSpacing(14)

        ml = QLabel("Mode"); ml.setStyleSheet("color:#8b949e; font-size:8pt;")
        ch.addWidget(ml)
        mr = QHBoxLayout(); mr.setSpacing(4)
        self.ber_btn = QPushButton("BER / FER"); self.ber_btn.setObjectName("mode")
        self.ber_btn.setCheckable(True)
        self.qkd_btn = QPushButton("QKD"); self.qkd_btn.setObjectName("mode")
        self.qkd_btn.setCheckable(True)
        self.ber_btn.clicked.connect(lambda: self._set_mode("BER/FER"))
        self.qkd_btn.clicked.connect(lambda: self._set_mode("QKD"))
        mr.addWidget(self.ber_btn); mr.addWidget(self.qkd_btn)
        ch.addLayout(mr)

        div = QFrame(); div.setFrameShape(QFrame.VLine)
        div.setStyleSheet("color:#30363d;"); div.setFixedWidth(1)
        ch.addWidget(div)

        xl = QLabel("Matrix"); xl.setStyleSheet("color:#8b949e; font-size:8pt;")
        ch.addWidget(xl)
        self.matrix_cb = QComboBox()
        self.matrix_cb.addItems(list(MATRICES.keys()))
        self.matrix_cb.setCurrentIndex(1)
        ch.addWidget(self.matrix_cb, 1)
        browse_btn = QPushButton("+ alist")
        browse_btn.clicked.connect(self._browse)
        ch.addWidget(browse_btn)

        div2 = QFrame(); div2.setFrameShape(QFrame.VLine)
        div2.setStyleSheet("color:#30363d;"); div2.setFixedWidth(1)
        ch.addWidget(div2)

        self.run_btn = QPushButton("▶  Run")
        self.run_btn.setObjectName("primary")
        self.run_btn.clicked.connect(self._run)
        ch.addWidget(self.run_btn)

        main.addWidget(cfg)

        par = self._panel()
        pv  = QVBoxLayout(par); pv.setContentsMargins(12, 10, 12, 10); pv.setSpacing(6)
        self.param_stack = QStackedWidget()
        self.param_stack.addWidget(self._make_ber_params())
        self.param_stack.addWidget(self._make_qkd_params())
        pv.addWidget(self.param_stack)
        main.addWidget(par)

        res = self._panel()
        rv  = QVBoxLayout(res); rv.setContentsMargins(0, 0, 0, 0); rv.setSpacing(0)

        self.table = QTableWidget()
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setAlternatingRowColors(True)
        self.table.verticalHeader().setVisible(False)
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.setMinimumHeight(180)
        rv.addWidget(self.table, 4)

        div3 = QFrame(); div3.setFixedHeight(1)
        div3.setStyleSheet("background:#21262d;")
        rv.addWidget(div3)

        self.output = QTextEdit(); self.output.setReadOnly(True)
        self.output.setMinimumHeight(90)
        rv.addWidget(self.output, 2)

        main.addWidget(res, 1)

        foot = QHBoxLayout(); foot.setSpacing(10)
        self.detail = QLabel("")
        self.detail.setStyleSheet("color:#8b949e; font-size:8pt;")
        foot.addWidget(self.detail); foot.addStretch()
        self.prog = QProgressBar()
        self.prog.setRange(0, 100); self.prog.setValue(0)
        self.prog.setFixedWidth(200); self.prog.setTextVisible(False)
        foot.addWidget(self.prog)
        self.pct = QLabel(""); self.pct.setStyleSheet("color:#8b949e; font-size:8pt;")
        foot.addWidget(self.pct)
        main.addLayout(foot)

        self.setStatusBar(QStatusBar())

    def _make_ber_params(self):
        f = QFrame(); lay = QGridLayout(f)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setHorizontalSpacing(10); lay.setVerticalSpacing(4)
        self.params = {}
        fields = [("SNR MIN (dB)", "snr_min", "1.0"),
                  ("SNR MAX (dB)", "snr_max", "4.0"),
                  ("STEPS",        "snr_steps","13"),
                  ("MAX ITER",     "max_iter", "50"),
                  ("TARGET FE",    "target_fe","100"),
                  ("MAX TRIALS",   "max_trials","100000"),
                  ("ATTENUATION α","attn",     "0.75")]
        for col, (lbl, key, val) in enumerate(fields):
            b = QVBoxLayout(); b.setSpacing(3)
            l = QLabel(lbl)
            l.setStyleSheet("color:#8b949e; font-size:8pt;")
            b.addWidget(l)
            e = QLineEdit(val); e.setAlignment(Qt.AlignCenter)
            b.addWidget(e); lay.addLayout(b, 0, col)
            self.params[key] = e
        for c in range(len(fields)): lay.setColumnStretch(c, 1)
        return f

    def _make_qkd_params(self):
        f = QFrame(); lay = QGridLayout(f)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setHorizontalSpacing(10); lay.setVerticalSpacing(4)
        self.qkd_p = {}
        fields = [("QBER MIN",       "qber_min",   "0.01"),
                  ("QBER MAX",       "qber_max",   "0.10"),
                  ("STEPS",          "qber_steps", "10"),
                  ("TRIALS / POINT", "qkd_trials", "50"),
                  ("MAX ITER",       "qkd_iter",   "50"),
                  ("HW MBPS",        "hw_mbps",    "7.5")]
        for col, (lbl, key, val) in enumerate(fields):
            b = QVBoxLayout(); b.setSpacing(3)
            l = QLabel(lbl)
            l.setStyleSheet("color:#8b949e; font-size:8pt;")
            b.addWidget(l)
            e = QLineEdit(val); e.setAlignment(Qt.AlignCenter)
            b.addWidget(e); lay.addLayout(b, 0, col)
            self.qkd_p[key] = e
        for c in range(len(fields)): lay.setColumnStretch(c, 1)
        lay.addWidget(QWidget(), 0, len(fields), 1, 1)
        return f

    def _set_mode(self, mode):
        ber = mode == "BER/FER"
        self.ber_btn.setChecked(ber); self.qkd_btn.setChecked(not ber)
        self.param_stack.setCurrentIndex(0 if ber else 1)
        headers = (["Eb/N0 (dB)", "BER", "FER", "Avg Iter", "Trials"]
                   if ber else
                   ["QBER", "FER", "Key Rate", "f", "SKR (Mbps)", "Secure"])
        self.table.setColumnCount(len(headers))
        self.table.setHorizontalHeaderLabels(headers)
        self.table.setRowCount(0)

    def mode(self): return "BER/FER" if self.ber_btn.isChecked() else "QKD"

    def _browse(self):
        p, _ = QFileDialog.getOpenFileName(
            self, "Select alist", str(PROJECT_ROOT/"matrices"),
            "ALIST (*.alist);;All (*)")
        if not p: return
        k = f"Custom · {Path(p).name}"
        MATRICES[k] = p
        self.matrix_cb.addItem(k)
        self.matrix_cb.setCurrentText(k)

    def _run(self):
        if self.running: return
        key  = self.matrix_cb.currentText()
        ref  = MATRICES.get(key, "")
        path = Path(ref) if Path(ref).is_absolute() else PROJECT_ROOT/ref
        if not path.exists():
            QMessageBox.critical(self, "Not found", str(path)); return
        try:
            params     = {k: v.text().strip() for k,v in self.params.items()}
            qkd_params = {k: v.text().strip() for k,v in self.qkd_p.items()}
        except Exception as e:
            QMessageBox.warning(self, "Error", str(e)); return

        self.table.setRowCount(0)
        self.output.clear()
        self.prog.setValue(0); self.pct.setText(""); self.detail.setText("")

        self.running    = True
        self.stop_event = threading.Event()
        self.run_btn.setEnabled(False)
        self.stop_btn.setEnabled(True)
        self.status_lbl.setText("RUNNING")
        self.status_lbl.setStyleSheet("color:#f0883e; font-weight:700; font-size:9pt;")

        self.worker_thread = QThread(self)
        self.worker = Worker(self.mode(), path, params, qkd_params, self.stop_event)
        self.worker.moveToThread(self.worker_thread)
        self.worker_thread.started.connect(self.worker.run)
        self.worker.log.connect(self._on_log)
        self.worker.progress.connect(self._on_prog)
        self.worker.ber_result.connect(self._on_ber)
        self.worker.qkd_result.connect(self._on_qkd)
        self.worker.failed.connect(self._on_fail)
        self.worker.finished.connect(self._on_done)
        self.worker.finished.connect(self.worker_thread.quit)
        self.worker_thread.finished.connect(self.worker.deleteLater)
        self.worker_thread.finished.connect(self.worker_thread.deleteLater)
        self.worker_thread.start()

    def _stop(self):
        if self.stop_event: self.stop_event.set()
        self.stop_btn.setEnabled(False)

    def _save(self):
        p, _ = QFileDialog.getSaveFileName(
            self, "Save output", "results.txt", "Text (*.txt);;All (*)")
        if p:
            Path(p).write_text(self.output.toPlainText(), encoding="utf-8")

    @Slot(str, str)
    def _on_log(self, text, tag):
        c = {"good":"#3fb950","warn":"#d29922","bad":"#f85149","sub":"#8b949e"}.get(tag,"#8b949e")
        self.output.setTextColor(QColor(c))
        self.output.append(text)
        self.output.verticalScrollBar().setValue(
            self.output.verticalScrollBar().maximum())

    @Slot(float, str)
    def _on_prog(self, v, s):
        v = max(0., min(100., v))
        self.prog.setValue(round(v))
        self.pct.setText(f"{v:.0f}%")
        self.detail.setText(s)

    @Slot(object)
    def _on_ber(self, r):
        row = self.table.rowCount(); self.table.insertRow(row)
        N, tr = r["N"], r["trials"]
        ber_s = f"<{1/(tr*N):.2e}" if r["ber_floor"] else f"{r['ber']:.3e}"
        fer_s = f"<{1/tr:.2e}"     if r["fer_floor"] else f"{r['fer']:.4f}"
        vals  = [f"{r['snr']:.2f}", ber_s, fer_s,
                 f"{r['avg']:.2f}", f"{tr:,}"]
        c = "#3fb950" if r["fer"]==0 else "#d29922" if r["fer"]<0.3 else "#f85149"
        self._add_row(row, vals, c)

    @Slot(object)
    def _on_qkd(self, r):
        row = self.table.rowCount(); self.table.insertRow(row)
        vals = [f"{r['qber']:.3f}", f"{r['fer']:.3f}", f"{r['kr']:.4f}",
                f"{r['f']:.2f}", f"{r['skr']:.3f}",
                "YES" if r["secure"] else "NO"]
        c = ("#3fb950" if r["secure"] and r["fer"]<0.1
             else "#d29922" if r["secure"] else "#f85149")
        self._add_row(row, vals, c)

    def _add_row(self, row, vals, colour):
        for col, v in enumerate(vals):
            item = QTableWidgetItem(v)
            item.setTextAlignment(Qt.AlignCenter)
            item.setForeground(QColor(colour))
            self.table.setItem(row, col, item)
        self.table.scrollToBottom()

    @Slot(str)
    def _on_fail(self, trace):
        self._on_log(trace, "bad")

    @Slot()
    def _on_done(self):
        self.running = False
        stopped = self.stop_event and self.stop_event.is_set()
        self.status_lbl.setText("STOPPED" if stopped else "READY")
        self.status_lbl.setStyleSheet(
            f"color:{'#f85149' if stopped else '#3fb950'}; font-weight:700; font-size:9pt;")
        if not stopped:
            self.prog.setValue(100); self.pct.setText("100%")
        self.run_btn.setEnabled(True)
        self.stop_btn.setEnabled(False)
        self.worker = self.worker_thread = self.stop_event = None


def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setStyleSheet(QSS)
    w = Reconciler()
    s = app.primaryScreen()
    if s:
        g = s.availableGeometry()
        ww = min(1400, max(1100, int(g.width() * 0.85)))
        wh = min(900,  max(680,  int(g.height() * 0.85)))
        w.resize(ww, wh)
        w.move(g.x()+(g.width()-ww)//2, g.y()+(g.height()-wh)//2)
    w.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
