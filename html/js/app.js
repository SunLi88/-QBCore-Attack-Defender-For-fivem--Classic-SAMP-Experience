'use strict';

// ── Resource name ──
var RESOURCE = (function() {
    try { return GetParentResourceName(); } catch(e) { return 'attackdefend'; }
})();

// ── Helpers ──
var $ = function(id) { return document.getElementById(id); };
var show = function(el) { if (el) el.classList.remove('hidden'); };
var hide = function(el) { if (el) el.classList.add('hidden'); };

function postNUI(action, data) {
    fetch('https://' + RESOURCE + '/' + action, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).catch(function() {});
}

function esc(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function fmtScore(score) {
    if (!score) return { atk: 0, def: 0 };
    if (Array.isArray(score)) return { atk: score[0] || 0, def: score[1] || 0 };
    return { atk: score[1] || score.atk || 0, def: score[2] || score.def || 0 };
}

// ── State ──
var State = { menuOpen: false, myId: null };

// ── Tabs ──
document.querySelectorAll('.tab').forEach(function(btn) {
    btn.addEventListener('click', function() {
        document.querySelectorAll('.tab').forEach(function(t) { t.classList.remove('active'); });
        document.querySelectorAll('.tab-content').forEach(function(t) { hide(t); });
        btn.classList.add('active');
        show($('tab-' + btn.dataset.tab));
    });
});

// ── Public API ──
var UI = window.UI = {
    joinTeam: function(t) { postNUI('joinTeam', { team: t }); UI.closeMenu(); },
    leaveGame: function()  { postNUI('leaveGame'); UI.closeMenu(); },
    closeMenu: function()  {
        State.menuOpen = false;
        hide($('menu'));
        postNUI('closeUI');
    },
    openMenu: function() {
        State.menuOpen = true;
        show($('menu'));
        postNUI('getLeaderboard');
    },
};

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && State.menuOpen) UI.closeMenu();
});

// ── Message dispatcher ──
window.addEventListener('message', function(ev) {
    var d = ev.data;
    if (!d || !d.action) return;
    var fn = handlers[d.action];
    if (fn) fn(d);
});

// ── Handlers ──
var _notifTimer;

var handlers = {

    openMenu:   function()  { UI.openMenu(); },
    closeMenu:  function()  { UI.closeMenu(); },
    toggleMenu: function()  { State.menuOpen ? UI.closeMenu() : UI.openMenu(); },

    showHUD:    function()  { show($('hud')); },
    hideHUD:    function()  { hide($('hud')); hide($('round-end')); },

    joined: function(d) {
        State.myId = d.myId || null;
        show($('hud'));
        if (d.data) renderHUD(d.data);
        var lbl   = d.team === 1 ? '⚔ ATTACKERS' : '🛡 DEFENDERS';
        var color = d.team === 1 ? '#ff2d78'      : '#00d4ff';
        flashNotif(lbl, color);
    },

    updateHUD: function(d) {
        if (d && d.data) renderHUD(d.data);
    },

    roundStart: function(d) {
        updateTimer(d.timeLeft || 180);
        flashNotif('ROUND ' + (d.round || 1), '#ffd64a');
        hide($('round-end'));
    },

    roundEnd: function(d) {
        showRoundEnd(d.winnerTeam, d.score, d.matchOver, d.playerStats, d.atkList, d.defList);
    },

    matchEnd: function(d) {
        var lbl = d.winner === 1 ? '🏆 ATTACKERS WIN'
                : d.winner === 2 ? '🏆 DEFENDERS WIN' : '🤝 DRAW';
        flashNotif(lbl, '#ffd64a', 6000);
        showRoundEnd(d.winner, d.score, true, null, d.atkList || [], d.defList || []);
    },

    playerDied: function() {
        flashNotif('💀 ELIMINATED', '#ff4444', 2500);
    },

    killFeed: function(d) {
        addKillFeed(d.data || d);
    },

    objectiveContested: function(d) {
        d.contested ? show($('cap-bar-wrap')) : hide($('cap-bar-wrap'));
        if (!d.contested) {
            var f = $('cap-bar-fill');
            if (f) f.style.width = '0%';
        }
    },

    nearObjective: function(d) {
        d.near ? show($('obj-hint')) : hide($('obj-hint'));
    },

    spectateMode: function(d) {
        d.active ? show($('spectate-bar')) : hide($('spectate-bar'));
    },

    spectateTarget: function(d) {
        var el = $('spectate-name');
        if (el) el.textContent = d.name || '—';
    },

    leaderboard: function(d) {
        renderLeaderboard(d.data || []);
    },

    expUpdate: function(d) {
        if (!d || typeof d !== 'object') return;
        var k  = parseInt(d.kills)  || 0;
        var de = parseInt(d.deaths) || 0;
        var ex = parseInt(d.exp)    || 0;
        setVal('kd-kills',  k);
        setVal('kd-deaths', de);
        setVal('kd-exp',    ex);
    },
};

// ── Render HUD ──
function renderHUD(data) {
    var s = fmtScore(data.score);
    setVal('score-atk', s.atk);
    setVal('score-def', s.def);
    setVal('round-num', (data.round || 1) + ' / ' + (data.maxRounds || 3));
    updateTimer(data.timeLeft || 0);

    var f = $('cap-bar-fill');
    if (f) f.style.width = (data.capProgress || 0) + '%';

    renderTeamList('atk-list', data.attackers || []);
    renderTeamList('def-list', data.defenders || []);

    var ca = $('cnt-atk'), cd = $('cnt-def');
    if (ca) ca.textContent = (data.attackers || []).length + ' players';
    if (cd) cd.textContent = (data.defenders || []).length + ' players';

    // Sync own stats from HUD data
    if (State.myId) {
        var all = (data.attackers || []).concat(data.defenders || []);
        for (var i = 0; i < all.length; i++) {
            if (String(all[i].id) === String(State.myId)) {
                setVal('kd-kills',  all[i].kills  || 0);
                setVal('kd-deaths', 0);  // deaths not in HUD row; use expUpdate for that
                setVal('kd-exp',    all[i].exp    || 0);
                break;
            }
        }
    }
}

function renderTeamList(id, players) {
    var el = $(id);
    if (!el) return;
    el.innerHTML = players.map(function(p) {
        var pct  = Math.max(0, Math.min(100, ((p.hp || 0) / 200) * 100));
        var dead = p.alive === false ? ' player-dead' : '';
        var col  = pct > 60 ? '#44ff88' : pct > 30 ? '#ffd64a' : '#ff4444';
        return '<div class="player-row' + dead + '">' +
            '<span class="player-name">' + esc(p.name) + '</span>' +
            '<div class="hp-bar"><div class="hp-fill" style="width:' + pct + '%;background:' + col + '"></div></div>' +
            '<span class="player-kills">' + (p.kills || 0) + '</span>' +
        '</div>';
    }).join('');
}

function updateTimer(secs) {
    var el = $('round-timer');
    if (!el) return;
    var m = Math.floor(secs / 60);
    var s = secs % 60;
    el.textContent = m + ':' + String(s).padStart(2, '0');
    secs <= 30 ? el.classList.add('danger') : el.classList.remove('danger');
}

function setVal(id, val) {
    var el = $(id);
    if (el) el.textContent = val;
}

// ── Kill feed ──
function addKillFeed(data) {
    var kf = $('kill-feed');
    if (!kf) return;
    var d = document.createElement('div');
    d.className = 'kf-entry';
    var kc = data.killerTeam === 1 ? 'kf-atk' : 'kf-def';
    var vc = data.victimTeam === 1 ? 'kf-atk' : 'kf-def';
    d.innerHTML =
        '<span class="' + kc + '">' + esc(String(data.killer)) + '</span>' +
        '<span style="color:#fff;font-size:.7rem">💀</span>' +
        '<span class="' + vc + '">' + esc(String(data.victim)) + '</span>';
    kf.prepend(d);
    setTimeout(function() {
        d.classList.add('fading');
        setTimeout(function() { if (d.parentNode) d.remove(); }, 500);
    }, 5000);
    while (kf.children.length > 6) kf.lastChild.remove();
}

// ── Flash notification ──
function flashNotif(text, color, ms) {
    var el = $('round-notif');
    if (!el) return;
    el.textContent = text;
    el.style.color = color || '#fff';
    el.style.borderColor = (color || '#fff') + '44';
    show(el);
    clearTimeout(_notifTimer);
    _notifTimer = setTimeout(function() { hide(el); }, ms || 2500);
}

// ── Round end screen ──
function showRoundEnd(winnerTeam, score, matchOver, playerStats, atkList, defList) {
    var sc = $('round-end');
    if (!sc) return;

    var text = '', color = '#fff';
    if (matchOver) {
        if (winnerTeam === 1)      { text = '🏆 ATTACKERS WIN THE MATCH'; color = 'var(--atk)'; }
        else if (winnerTeam === 2) { text = '🏆 DEFENDERS WIN THE MATCH'; color = 'var(--def)'; }
        else                       { text = '🤝 MATCH DRAW';              color = '#ffd64a'; }
    } else {
        if (winnerTeam === 1)      { text = '⚔ ATTACKERS WIN THE ROUND'; color = 'var(--atk)'; }
        else if (winnerTeam === 2) { text = '🛡 DEFENDERS WIN THE ROUND'; color = 'var(--def)'; }
        else if (winnerTeam === 0) { text = '🤝 ROUND DRAW';             color = '#ffd64a'; }
        else                       { text = '⏱ TIME OUT';                color = '#ffd64a'; }
    }

    var rew = $('re-winner');
    if (rew) { rew.textContent = text; rew.style.color = color; }

    var s = fmtScore(score);
    setVal('re-atk', s.atk);
    setVal('re-def', s.def);

    var fmtList = function(arr) {
        return (arr || []).map(function(p) {
            return '<div class="re-row">' +
                '<span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + esc(p.name || 'Unknown') + '</span>' +
                '<span class="re-kd">'  + (p.kills  || 0) + '</span>' +
                '<span class="re-kd">'  + (p.deaths || 0) + '</span>' +
                '<span class="re-exp">' + (p.exp    || 0) + '</span>' +
            '</div>';
        }).join('') || '<div class="re-row" style="opacity:.4"><span>No players</span><span>—</span><span>—</span><span>—</span></div>';
    };

    var ral = $('re-atk-list'), rdl = $('re-def-list');
    if (ral) ral.innerHTML = fmtList(atkList);
    if (rdl) rdl.innerHTML = fmtList(defList);

    var you = $('re-you');
    if (you && playerStats) {
        you.innerHTML =
            '<span style="color:var(--gold);font-weight:700;letter-spacing:1px;margin-right:12px">' + esc(playerStats.name || '') + '</span>' +
            '<span style="font-family:var(--mono);color:#fff">K:' + (playerStats.kills || 0) + '  D:' + (playerStats.deaths || 0) + '</span>' +
            '<span style="font-family:var(--mono);color:var(--exp);margin-left:12px">+' + (playerStats.exp || 0) + ' EXP</span>';
        show(you);
    } else if (you) {
        hide(you);
    }

    show(sc);
    setTimeout(function() { hide(sc); }, matchOver ? 6000 : 10000);
}

// ── Leaderboard ──
function renderLeaderboard(rows) {
    var tb = $('lb-body');
    if (!tb) return;
    if (!rows || !rows.length) {
        tb.innerHTML = '<tr><td colspan="5" style="text-align:center;opacity:.4;padding:20px">No data yet</td></tr>';
        return;
    }
    tb.innerHTML = rows.map(function(r, i) {
        return '<tr>' +
            '<td>' + (i + 1) + '</td>' +
            '<td>' + esc(r.name || '—') + '</td>' +
            '<td style="color:var(--gold)">' + (r.kills || 0) + '</td>' +
            '<td>' + (r.deaths || 0) + '</td>' +
            '<td>' + (r.matches || 0) + '</td>' +
        '</tr>';
    }).join('');
}
