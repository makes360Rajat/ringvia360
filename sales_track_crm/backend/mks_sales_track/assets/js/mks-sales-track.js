/*
 * MKS Sales Track - page script.
 *
 * One file for every screen the module has: the activity lists, the Devices
 * page, a device's own page and Settings. Which part runs is decided by
 * window.mksSalesTrack.page, printed by the module just before this file.
 *
 * Loaded from app_admin_footer, after Perfex has printed jQuery and main.js,
 * so initDataTable, init_lead and alert_float all exist by the time this runs.
 * Written as ES5 inside a strict IIFE: every name is declared at the top of
 * its function, because an undeclared assignment under 'use strict' throws
 * inside a callback with no visible symptom beyond a feature that does nothing.
 */
(function () {
    'use strict';

    var cfg = window.mksSalesTrack || {};
    var $ = window.jQuery;

    if (!$) {
        return;
    }

    /* ---------------------------------------------------------------------
     * Shared
     * ------------------------------------------------------------------ */

    function text(key, fallback) {
        return (cfg.text && cfg.text[key]) ? cfg.text[key] : (fallback || '');
    }

    function esc(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function notify(type, message) {
        if (typeof window.alert_float === 'function' && message) {
            window.alert_float(type, message);
        }
    }

    /**
     * Every JSON reply from the module carries the current CSRF hash. Copying
     * it back keeps a page that has been open for hours working after the
     * token changes.
     */
    function refreshCsrf(response) {
        if (!response || !response.csrf || typeof window.csrfData === 'undefined') {
            return;
        }

        window.csrfData.hash = response.csrf.hash;

        if (window.csrfData.formatted) {
            window.csrfData.formatted[response.csrf.name] = response.csrf.hash;
            $.ajaxSetup({ data: window.csrfData.formatted });
        }
    }

    function post(url, data) {
        return $.ajax({
            url: url,
            type: 'POST',
            data: data || {},
            dataType: 'json'
        }).done(refreshCsrf).fail(function (xhr) {
            refreshCsrf(xhr && xhr.responseJSON);
        });
    }

    function failMessage(xhr) {
        return (xhr && xhr.responseJSON && xhr.responseJSON.message) ? xhr.responseJSON.message : text('failed', 'That did not work.');
    }

    function copyText(value) {
        var area;

        if (navigator.clipboard && window.isSecureContext) {
            return navigator.clipboard.writeText(value);
        }

        area = document.createElement('textarea');
        area.value = value;
        area.setAttribute('readonly', '');
        area.style.position = 'fixed';
        area.style.opacity = '0';
        document.body.appendChild(area);
        area.select();

        try {
            document.execCommand('copy');
        } catch (e) {
            // Nothing else to try; the address is still on screen to select.
        }

        document.body.removeChild(area);

        return null;
    }

    function bindCopy() {
        $(document).on('click', '.mks-sales-track-copy', function () {
            var target = document.querySelector(this.getAttribute('data-copy'));

            if (!target) {
                return;
            }

            copyText(target.textContent.trim());
            notify('success', text('copied', 'Copied.'));
        });
    }

    /* ---------------------------------------------------------------------
     * Activity lists
     * ------------------------------------------------------------------ */

    function renderTiles(tiles) {
        var box = document.getElementById('mks-sales-track-kpis');
        var html = '';
        var i;
        var tile;

        if (!box || !tiles || !tiles.length) {
            return;
        }

        for (i = 0; i < tiles.length; i++) {
            tile = tiles[i];
            html += '<div class="mks-sales-track-kpi mks-sales-track-tone-' + esc(tile.tone) + '">'
                + '<span class="mks-sales-track-kpi-icon"><i class="' + esc(tile.icon) + '" aria-hidden="true"></i></span>'
                + '<div class="mks-sales-track-kpi-body">'
                + '<span class="mks-sales-track-kpi-label">' + esc(tile.label) + '</span>'
                + '<span class="mks-sales-track-kpi-value">' + esc(tile.value) + '</span>'
                + (tile.hint ? '<span class="mks-sales-track-kpi-hint">' + esc(tile.hint) + '</span>' : '')
                + '</div></div>';
        }

        box.innerHTML = html;
    }

    function initList() {
        var $table = $('table.table-mks-sales-track-events');
        var api;
        var params = {
            mks_st_range: '#mks-st-range',
            mks_st_from: '#mks-st-from',
            mks_st_to: '#mks-st-to',
            mks_st_staff: '#mks-st-staff',
            mks_st_direction: '#mks-st-direction',
            mks_st_match: '#mks-st-match',
            mks_st_device: '#mks-st-device',
            mks_st_outcome: '#mks-st-outcome'
        };

        if (!$table.length || typeof window.initDataTable !== 'function' || !cfg.urls || !cfg.table) {
            return;
        }

        // Bound before the table starts, so the very first reply fills the tiles.
        $table.on('xhr.dt', function (e, settings, json) {
            if (json && json.mks_st_summary) {
                renderTiles(json.mks_st_summary);
            }
        });

        // A flat [index, direction] pair: initDataTable wraps a nested one again.
        window.initDataTable($table, cfg.urls.table, cfg.table.not_searchable, cfg.table.not_sortable, params, cfg.table.order);
        api = $table.DataTable();

        function reload() {
            api.ajax.reload();
        }

        $('#mks-sales-track-range').on('click', '.mks-sales-track-segment-btn', function () {
            var value = this.getAttribute('data-value');

            $(this).addClass('is-active').siblings().removeClass('is-active');
            $('#mks-st-range').val(value);
            $('#mks-sales-track-dates').toggleClass('mks-sales-track-is-hidden', value !== 'custom');
            reload();
        });

        $('#mks-st-from, #mks-st-to, #mks-st-staff, #mks-st-direction, #mks-st-match, #mks-st-device, #mks-st-outcome').on('change', reload);

        $('#mks-sales-track-reset').on('click', function () {
            $('#mks-st-staff, #mks-st-direction, #mks-st-match, #mks-st-device, #mks-st-outcome').val('');
            $('#mks-st-range').val('7d');
            $('#mks-sales-track-range .mks-sales-track-segment-btn').removeClass('is-active')
                .filter('[data-value="7d"]').addClass('is-active');
            $('#mks-sales-track-dates').addClass('mks-sales-track-is-hidden');
            api.search('');
            reload();
        });

        $(document).on('click', '.mks-sales-track-text-toggle', function () {
            var $box = $(this).closest('.mks-sales-track-text');
            var $full = $box.find('.mks-sales-track-text-full');
            var showingFull = !$full.hasClass('mks-sales-track-is-hidden');

            $full.toggleClass('mks-sales-track-is-hidden', showingFull);
            $box.find('.mks-sales-track-text-short').toggleClass('mks-sales-track-is-hidden', !showingFull);
            $(this).text(showingFull ? this.getAttribute('data-more') : this.getAttribute('data-less'));
        });

        $(document).on('click', '.mks-sales-track-delete-event', function () {
            var id = this.getAttribute('data-id');

            if (!window.confirm(text('confirmDelete', 'Delete this record?'))) {
                return;
            }

            post(cfg.urls.delete, { id: id }).done(function () {
                notify('success', text('deleted', 'Deleted.'));
                api.ajax.reload(null, false);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            });
        });

        initCreateLead(api);
        initPlayer($table);
    }

    /**
     * Opens Perfex's own New Lead window and fills in the number. Saving it
     * fires lead_created, which links this number's past activity to the lead.
     */
    function initCreateLead(api) {
        var $modal = $('#lead-modal');
        var pending = false;

        $(document).on('click', '.mks-sales-track-create-lead', function () {
            var number = this.getAttribute('data-number') || '';
            var name = this.getAttribute('data-name') || '';
            var tries = 0;

            if (typeof window.init_lead !== 'function') {
                return;
            }

            function fill() {
                var $form = $modal.find('#lead_form');
                var $phone;
                var $name;

                if (!$form.length) {
                    tries++;

                    if (tries < 50) {
                        window.setTimeout(fill, 100);
                    }

                    return;
                }

                $phone = $form.find('input[name="phonenumber"]');
                $name = $form.find('input[name="name"]');

                if ($phone.length && !$phone.val()) {
                    $phone.val(number).trigger('change');
                }

                if ($name.length && !$name.val() && name) {
                    $name.val(name).trigger('change');
                }
            }

            pending = true;
            window.init_lead();
            fill();
        });

        $modal.on('hidden.bs.modal', function () {
            if (pending) {
                pending = false;
                api.ajax.reload(null, false);
            }
        });
    }

    /**
     * One floating player for the whole list: a single audio element, so
     * scrolling through hundreds of calls never builds hundreds of players.
     */
    function initPlayer($table) {
        var player = document.getElementById('mks-sales-track-player');
        var audio = document.getElementById('mks-sales-track-audio');
        var toggle = document.getElementById('mks-sales-track-player-toggle');
        var seek = document.getElementById('mks-sales-track-player-seek');
        var current = document.getElementById('mks-sales-track-player-current');
        var total = document.getElementById('mks-sales-track-player-total');
        var title = document.getElementById('mks-sales-track-player-title');
        var sub = document.getElementById('mks-sales-track-player-sub');
        var speed = document.getElementById('mks-sales-track-player-speed');
        var download = document.getElementById('mks-sales-track-player-download');
        var close = document.getElementById('mks-sales-track-player-close');
        var speeds = [1, 1.25, 1.5, 2];
        var speedIndex = 0;
        var activeId = null;
        var seeking = false;
        var playIcon = '<i class="fa-solid fa-play" aria-hidden="true"></i>';
        var pauseIcon = '<i class="fa-solid fa-pause" aria-hidden="true"></i>';

        if (!player || !audio || !toggle || !seek) {
            return;
        }

        function pad(n) {
            return n < 10 ? '0' + n : String(n);
        }

        function clock(seconds) {
            var h;
            var m;
            var s;

            if (!isFinite(seconds) || seconds < 0) {
                seconds = 0;
            }

            seconds = Math.floor(seconds);
            h = Math.floor(seconds / 3600);
            m = Math.floor((seconds % 3600) / 60);
            s = seconds % 60;

            return h > 0 ? h + ':' + pad(m) + ':' + pad(s) : m + ':' + pad(s);
        }

        function setProgress(percent) {
            seek.style.setProperty('--mks-st-progress', Math.max(0, Math.min(100, percent)) + '%');
        }

        function markRows() {
            var playing = activeId !== null && !audio.paused;

            $table.find('tr.is-playing').removeClass('is-playing');
            $table.find('.mks-sales-track-play[data-src]').removeClass('is-playing').html(playIcon);

            if (activeId === null) {
                return;
            }

            $table.find('.mks-sales-track-play[data-id="' + activeId + '"]').each(function () {
                $(this).addClass('is-playing').html(playing ? pauseIcon : playIcon);
                $(this).closest('tr').addClass('is-playing');
            });
        }

        function updateToggle() {
            toggle.innerHTML = audio.paused ? playIcon : pauseIcon;
            markRows();
        }

        function start() {
            var promise = audio.play();

            if (promise && typeof promise.catch === 'function') {
                promise.catch(function () {
                    updateToggle();
                });
            }
        }

        function open(button) {
            var id = button.getAttribute('data-id');

            if (activeId === id && audio.getAttribute('src')) {
                if (audio.paused) {
                    start();
                } else {
                    audio.pause();
                }

                return;
            }

            activeId = id;
            audio.setAttribute('src', button.getAttribute('data-src'));
            audio.playbackRate = speeds[speedIndex];
            title.textContent = button.getAttribute('data-title') || '';
            sub.textContent = button.getAttribute('data-sub') || '';
            download.setAttribute('href', button.getAttribute('data-download') || '#');
            download.style.display = button.getAttribute('data-download') ? '' : 'none';
            seek.value = 0;
            setProgress(0);
            current.textContent = '0:00';
            total.textContent = '0:00';
            player.classList.add('is-open');
            player.setAttribute('aria-hidden', 'false');
            start();
        }

        function shut() {
            audio.pause();
            audio.removeAttribute('src');
            audio.load();
            activeId = null;
            player.classList.remove('is-open');
            player.setAttribute('aria-hidden', 'true');
            updateToggle();
        }

        $(document).on('click', '.mks-sales-track-play[data-src]', function (e) {
            e.preventDefault();
            open(this);
        });

        toggle.addEventListener('click', function () {
            if (!audio.getAttribute('src')) {
                return;
            }

            if (audio.paused) {
                start();
            } else {
                audio.pause();
            }
        });

        audio.addEventListener('play', updateToggle);
        audio.addEventListener('pause', updateToggle);

        audio.addEventListener('ended', function () {
            seek.value = 0;
            setProgress(0);
            updateToggle();
        });

        audio.addEventListener('loadedmetadata', function () {
            total.textContent = clock(audio.duration);
        });

        audio.addEventListener('durationchange', function () {
            total.textContent = clock(audio.duration);
        });

        audio.addEventListener('timeupdate', function () {
            var duration = audio.duration;

            if (seeking || !isFinite(duration) || duration <= 0) {
                return;
            }

            seek.value = Math.round(audio.currentTime / duration * 1000);
            setProgress(audio.currentTime / duration * 100);
            current.textContent = clock(audio.currentTime);
        });

        audio.addEventListener('error', function () {
            if (audio.getAttribute('src')) {
                notify('warning', text('cannotPlay', 'This recording could not be played.'));
                shut();
            }
        });

        seek.addEventListener('input', function () {
            var duration = audio.duration;

            seeking = true;
            setProgress(seek.value / 10);

            if (isFinite(duration)) {
                current.textContent = clock(duration * seek.value / 1000);
            }
        });

        seek.addEventListener('change', function () {
            var duration = audio.duration;

            if (isFinite(duration)) {
                audio.currentTime = duration * seek.value / 1000;
            }

            seeking = false;
        });

        speed.addEventListener('click', function () {
            speedIndex = (speedIndex + 1) % speeds.length;
            audio.playbackRate = speeds[speedIndex];
            speed.textContent = speeds[speedIndex] + 'x';
        });

        close.addEventListener('click', shut);

        // A redraw rebuilds every row, so the playing row is marked again.
        $table.on('draw.dt', markRows);
    }

    /* ---------------------------------------------------------------------
     * Outcomes (lists and Follow-ups)
     * ------------------------------------------------------------------ */

    /**
     * The Set Outcome window. onSaved runs after a successful save.
     */
    function bindOutcomes(onSaved) {
        var $modal = $('#mks-sales-track-outcome-modal');

        if (!$modal.length || !cfg.outcome) {
            return;
        }

        function pad(n) {
            return (n < 10 ? '0' : '') + n;
        }

        $(document).on('click', '.mks-sales-track-outcome-edit', function () {
            var $button = $(this);
            var current = $button.attr('data-outcome') || '';

            $('#mks-st-o-id').val($button.attr('data-id'));
            $modal.find('input[name="mks_st_o_outcome"]').prop('checked', false).filter(function () {
                return this.value === current;
            }).prop('checked', true);
            $('#mks-st-o-note').val($button.attr('data-note') || '');
            $('#mks-st-o-follow').val($button.attr('data-follow') || '');
            $('#mks-st-o-status').val('0');
            $('#mks-st-o-lead').prop('checked', false);
            $('#mks-st-o-lead-wrap').toggleClass('mks-sales-track-is-hidden', $button.attr('data-lead') !== '0');
            $modal.modal('show');
        });

        // Outcomes that call for a follow-up suggest tomorrow at ten.
        $modal.on('change', 'input[name="mks_st_o_outcome"]', function () {
            if ((cfg.outcome.followUps || []).indexOf(this.value) !== -1 && !$('#mks-st-o-follow').val()) {
                var d = new Date(Date.now() + 86400000);

                $('#mks-st-o-follow').val(d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + 'T10:00');
            }
        });

        $('#mks-st-o-save').on('click', function () {
            var $button = $(this);
            var outcome = $modal.find('input[name="mks_st_o_outcome"]:checked').val();

            if (!outcome) {
                notify('warning', cfg.outcome.choose || 'Choose an outcome.');

                return;
            }

            $button.prop('disabled', true);

            post(cfg.outcome.url, {
                id: $('#mks-st-o-id').val(),
                outcome: outcome,
                note: $('#mks-st-o-note').val(),
                follow_up: $('#mks-st-o-follow').val(),
                lead_status: $('#mks-st-o-status').val(),
                create_lead: $('#mks-st-o-lead').is(':checked') ? '1' : '0'
            }).done(function (data) {
                $modal.modal('hide');
                notify('success', data && data.message);

                if (typeof onSaved === 'function') {
                    onSaved();
                }
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            }).always(function () {
                $button.prop('disabled', false);
            });
        });
    }

    /* ---------------------------------------------------------------------
     * Click to call (every page that carries Call buttons, including the
     * lead window and customer pages)
     * ------------------------------------------------------------------ */

    function bindDial() {
        if (!cfg.dial || !cfg.dial.url) {
            return;
        }

        $(document).on('click', '.mks-sales-track-dial', function (e) {
            var $button = $(this);

            e.preventDefault();
            e.stopPropagation();

            if ($button.prop('disabled')) {
                return;
            }

            $button.prop('disabled', true);

            post(cfg.dial.url, { number: $button.attr('data-number'), name: $button.attr('data-name') || '' }).done(function (data) {
                notify('success', data && data.message);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            }).always(function () {
                window.setTimeout(function () {
                    $button.prop('disabled', false);
                }, 3000);
            });
        });
    }

    /* ---------------------------------------------------------------------
     * Best Pitches (lists and the library)
     * ------------------------------------------------------------------ */

    function bindPitches(onSaved) {
        var $modal = $('#mks-sales-track-pitch-modal');

        function save(id, action, extra) {
            return post(cfg.pitch.url, $.extend({ id: id, action: action }, extra || {})).done(function (data) {
                notify('success', data && data.message);

                if (typeof onSaved === 'function') {
                    onSaved();
                }
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            });
        }

        $(document).on('click', '.mks-sales-track-pitch', function () {
            var $button = $(this);

            $('#mks-st-p-id').val($button.attr('data-id'));
            $('#mks-st-p-category').val($button.attr('data-category') || '');
            $('#mks-st-p-note').val($button.attr('data-note') || '');
            $('#mks-st-p-moments').val($button.attr('data-moments') || '');
            $modal.find('[data-pitch-action="remove"]').toggleClass('mks-sales-track-is-hidden', !(cfg.pitch.manager && $button.attr('data-state') !== '0'));
            $modal.modal('show');
        });

        $modal.on('click', '[data-pitch-action]', function () {
            var action = this.getAttribute('data-pitch-action');

            save($('#mks-st-p-id').val(), action, {
                category: $('#mks-st-p-category').val(),
                note: $('#mks-st-p-note').val(),
                moments: $('#mks-st-p-moments').val()
            }).done(function () {
                $modal.modal('hide');
            });
        });

        $(document).on('click', '.mks-sales-track-pitch-act', function () {
            save(this.getAttribute('data-id'), this.getAttribute('data-action'));
        });

        // A moment plays its card's recording from that second.
        $(document).on('click', '.mks-sales-track-moment', function () {
            var audio = $(this).closest('.mks-sales-track-pitch-card').find('audio').get(0);

            if (audio) {
                audio.currentTime = parseInt(this.getAttribute('data-t'), 10) || 0;
                audio.play();
            }
        });
    }

    /* ---------------------------------------------------------------------
     * AI insights (lists)
     * ------------------------------------------------------------------ */

    function bindAi(reload) {
        var $modal = $('#mks-sales-track-ai-modal');

        if (!cfg.ai) {
            return;
        }

        $(document).on('click', '.mks-sales-track-ai-open', function () {
            $('#mks-sales-track-ai-body').html('<p class="mks-sales-track-muted">' + esc(text('working', 'Working...')) + '</p>');
            $modal.modal('show');
            $.get(cfg.ai.view + encodeURIComponent(this.getAttribute('data-id'))).done(function (html) {
                $('#mks-sales-track-ai-body').html(html);
            }).fail(function () {
                $('#mks-sales-track-ai-body').html('<p>' + esc(text('failed', 'That did not work.')) + '</p>');
            });
        });

        $(document).on('click', '.mks-sales-track-ai-run', function () {
            var $button = $(this);

            $button.prop('disabled', true).text(cfg.ai.working);

            post(cfg.ai.run, { id: $button.attr('data-id') }).done(function (data) {
                notify('success', data && data.message);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            }).always(reload);
        });

        $(document).on('click', '.mks-sales-track-ai-use', function () {
            var $button = $(this);

            $button.prop('disabled', true);

            post(cfg.ai.use, { id: $button.attr('data-id') }).done(function (data) {
                notify('success', data && data.message);
                $modal.modal('hide');
                reload();
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
                $button.prop('disabled', false);
            });
        });
    }

    /* ---------------------------------------------------------------------
     * Call lists
     * ------------------------------------------------------------------ */

    function initLists() {
        var $form  = $('#mks-sales-track-list-form');
        var timer  = null;

        function preview() {
            post(cfg.urls.preview, $form.serialize()).done(function (data) {
                $('.mks-sales-track-list-preview').text((data && data.message) || '');
            });
        }

        $form.on('change input', '.mks-sales-track-list-filter', function () {
            window.clearTimeout(timer);
            timer = window.setTimeout(preview, 400);
        });

        $('#mks-sales-track-list-modal').on('shown.bs.modal', preview);

        $form.on('submit', function () {
            var $submit = $form.find('[type="submit"]');

            $submit.prop('disabled', true);

            post(cfg.urls.save, $form.serialize()).done(function (data) {
                notify('success', data && data.message);
                window.location.href = window.location.pathname + '?id=' + encodeURIComponent(data.id);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
                $submit.prop('disabled', false);
            });

            return false;
        });

        $(document).on('click', '.mks-sales-track-list-act', function () {
            var button  = this;
            var confirm = button.getAttribute('data-confirm');

            if (confirm && !window.confirm(confirm)) {
                return;
            }

            post(cfg.urls.action, {
                action: button.getAttribute('data-action'),
                id: button.getAttribute('data-id') || '',
                lead: button.getAttribute('data-lead') || '',
                number: button.getAttribute('data-number') || ''
            }).done(function (data) {
                notify('success', data && data.message);
                window.setTimeout(function () {
                    window.location.reload();
                }, 400);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            });
        });
    }

    /* ---------------------------------------------------------------------
     * Callback queue
     * ------------------------------------------------------------------ */

    function initQueue() {
        $(document).on('click', '.mks-sales-track-resolve', function () {
            var $button = $(this);
            var id = $button.attr('data-id');

            $button.prop('disabled', true);

            post(cfg.urls.resolve, { id: id }).done(function () {
                $('#mks-sales-track-queue-' + id).fadeOut(200);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
                $button.prop('disabled', false);
            });
        });
    }

    /* ---------------------------------------------------------------------
     * Pairing panel (Add Device window and the device page)
     * ------------------------------------------------------------------ */

    /**
     * Show a code in a pairing panel, count it down, and poll until the phone
     * pairs or the code runs out. Returns a function that stops both timers.
     */
    function startPairing($panel, data, onPaired) {
        var expiresAt = Date.now() + (parseInt(data.expires_in, 10) || 0) * 1000;
        var clockTimer = null;
        var pollTimer = null;

        function stop() {
            if (clockTimer) {
                window.clearInterval(clockTimer);
                clockTimer = null;
            }

            if (pollTimer) {
                window.clearInterval(pollTimer);
                pollTimer = null;
            }
        }

        function show(part) {
            $panel.find('.mks-sales-track-pairing-wait').toggleClass('mks-sales-track-is-hidden', part !== 'wait');
            $panel.find('.mks-sales-track-pairing-done').toggleClass('mks-sales-track-is-hidden', part !== 'done');
            $panel.find('.mks-sales-track-pairing-expired').toggleClass('mks-sales-track-is-hidden', part !== 'expired');
        }

        function tick() {
            var left = Math.max(0, Math.round((expiresAt - Date.now()) / 1000));
            var hours = Math.floor(left / 3600);
            var minutes = Math.floor((left % 3600) / 60);
            var seconds = left % 60;
            var label = (hours > 0 ? hours + ':' + (minutes < 10 ? '0' : '') : '') + minutes + ':' + (seconds < 10 ? '0' : '') + seconds;

            $panel.find('.mks-sales-track-pairing-expiry').text(text('expiresIn', 'Expires in {t}').replace('{t}', label));

            if (left <= 0) {
                stop();
                show('expired');
            }
        }

        function poll() {
            $.getJSON(cfg.urls.status, { id: data.code_id }).done(function (reply) {
                refreshCsrf(reply);

                if (!reply || !reply.success) {
                    return;
                }

                if (reply.state === 'paired') {
                    stop();
                    $panel.find('.mks-sales-track-pairing-done-text').text(text('paired', 'Paired: {name}').replace('{name}', reply.model || reply.device || ''));
                    show('done');

                    if (typeof onPaired === 'function') {
                        onPaired(reply);
                    }
                } else if (reply.state === 'expired') {
                    stop();
                    show('expired');
                }
            });
        }

        // Pairing is by the 6-digit code only: no QR is drawn.
        $panel.find('.mks-sales-track-pairing-qr').addClass('mks-sales-track-is-hidden').empty();

        $panel.find('.mks-sales-track-pairing-code').text(data.code || '');
        $panel.find('.mks-sales-track-pairing-site').text(data.site || '');
        show('wait');
        tick();
        clockTimer = window.setInterval(tick, 1000);

        if (data.code_id) {
            pollTimer = window.setInterval(poll, 3000);
        }

        return stop;
    }

    /** The values typed into a device form, keyed by data-field. */
    function deviceForm($scope) {
        var values = { id: $scope.find('.mks-sales-track-form-id').val() || '' };

        $scope.find('[data-field]').each(function () {
            values[this.getAttribute('data-field')] = $(this).val();
        });

        return values;
    }

    function bindDemo() {
        $('.mks-sales-track-demo').on('click', function () {
            var $button = $(this);
            var action = $button.attr('data-action');

            if (!window.confirm(action === 'remove' ? text('confirmDemoOut') : text('confirmDemoIn'))) {
                return;
            }

            $button.prop('disabled', true).text(text('working', 'Working...'));

            post(cfg.urls.demo, { action: action }).done(function (data) {
                notify('success', data && data.message);
                window.setTimeout(function () {
                    window.location.reload();
                }, 700);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
                $button.prop('disabled', false);
            });
        });
    }

    /* ---------------------------------------------------------------------
     * Devices
     * ------------------------------------------------------------------ */

    function initDevices() {
        var $modal = $('#mks-sales-track-device-modal');
        var stopPairing = null;
        var reloadOnClose = false;

        function step(name) {
            $modal.find('[data-step]').addClass('mks-sales-track-is-hidden').filter('[data-step="' + name + '"]').removeClass('mks-sales-track-is-hidden');
        }

        bindDemo();

        $('#mks-sales-track-add-device').on('click', function () {
            $modal.find('[data-field]').val('');
            step('form');
            $modal.modal('show');
        });

        $modal.find('.mks-sales-track-device-save').on('click', function () {
            var $button = $(this);

            $button.prop('disabled', true);

            post(cfg.urls.save, deviceForm($modal.find('.mks-sales-track-device-form'))).done(function (data) {
                reloadOnClose = true;
                $modal.find('.mks-sales-track-device-open').attr('href', data.url || '#');
                step('pair');
                stopPairing = startPairing($modal.find('.mks-sales-track-pairing'), data);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            }).always(function () {
                $button.prop('disabled', false);
            });
        });

        $modal.on('hidden.bs.modal', function () {
            if (stopPairing) {
                stopPairing();
                stopPairing = null;
            }

            if (reloadOnClose) {
                window.location.reload();
            }
        });
    }

    /* ---------------------------------------------------------------------
     * One device
     * ------------------------------------------------------------------ */

    function initDevice() {
        var id = cfg.device;
        var $card = $('#mks-sales-track-device-pairing');
        var stopPairing = null;

        function pairingOn(data) {
            if (stopPairing) {
                stopPairing();
            }

            $card.removeClass('mks-sales-track-is-hidden');
            stopPairing = startPairing($card.find('.mks-sales-track-pairing'), data, function () {
                window.setTimeout(function () {
                    window.location.reload();
                }, 1500);
            });
        }

        // A code issued earlier and still live is shown again on arrival.
        if (cfg.code && $card.length) {
            pairingOn({
                code_id: cfg.code.id,
                expires_in: cfg.code.expires_in,
                code: $card.attr('data-code'),
                qr: $card.attr('data-qr'),
                site: $card.attr('data-site')
            });
        }

        $('.mks-sales-track-device-code').on('click', function () {
            var $button = $(this);

            if ($button.attr('data-bound') === '1' && !window.confirm(text('confirmCode'))) {
                return;
            }

            $button.prop('disabled', true);

            post(cfg.urls.code, { id: id }).done(function (data) {
                pairingOn(data);
                $('html, body').animate({ scrollTop: $card.offset().top - 90 }, 250);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            }).always(function () {
                $button.prop('disabled', false);
            });
        });

        $('.mks-sales-track-device-act').on('click', function () {
            var action = this.getAttribute('data-action');
            var questions = { revoke: text('confirmRevoke'), 'delete': text('confirmDelete') };

            if (questions[action] && !window.confirm(questions[action])) {
                return;
            }

            post(cfg.urls.action, { id: id, action: action }).done(function (data) {
                if (data && data.url) {
                    window.location.href = data.url;

                    return;
                }

                if (data && data.message) {
                    notify('success', data.message);
                }

                window.setTimeout(function () {
                    window.location.reload();
                }, 600);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            });
        });

        $('#mks-sales-track-device-modal .mks-sales-track-device-save').on('click', function () {
            var $button = $(this);

            $button.prop('disabled', true);

            post(cfg.urls.save, deviceForm($('#mks-sales-track-device-modal .mks-sales-track-device-form'))).done(function () {
                window.location.reload();
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
                $button.prop('disabled', false);
            });
        });
    }

    /* ---------------------------------------------------------------------
     * Settings
     * ------------------------------------------------------------------ */

    function initSettings() {
        // The model picker: the models this key may actually use.
        $('input[name="mks_st[gemini_model]"]').attr('list', 'mks-sales-track-models');

        $('.mks-sales-track-ai-models').on('click', function () {
            var $button = $(this);

            $button.prop('disabled', true);

            post($button.attr('data-url'), {}).done(function (data) {
                var list = document.getElementById('mks-sales-track-models');

                list.innerHTML = '';
                $.each((data && data.models) || [], function (i, model) {
                    var option = document.createElement('option');

                    option.value = model.name;
                    option.label = model.label;
                    list.appendChild(option);
                });
                notify('success', data && data.message);
                $('input[name="mks_st[gemini_model]"]').trigger('focus');
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            }).always(function () {
                $button.prop('disabled', false);
            });
        });

        $('.mks-sales-track-ai-test').on('click', function () {
            var $button = $(this);

            $button.prop('disabled', true);

            post($button.attr('data-url'), {}).done(function (data) {
                notify('success', data && data.message);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            }).always(function () {
                $button.prop('disabled', false);
            });
        });

        $('.mks-sales-track-drive-disconnect').on('click', function () {
            var $button = $(this);

            $button.prop('disabled', true);

            post($button.attr('data-url'), {}).done(function (data) {
                notify('success', data && data.message);
                window.setTimeout(function () {
                    window.location.reload();
                }, 600);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
                $button.prop('disabled', false);
            });
        });

        $('.mks-sales-track-report-test').on('click', function () {
            var $button = $(this);

            $button.prop('disabled', true);

            post($button.attr('data-url'), {}).done(function (data) {
                notify('success', data && data.message);
            }).fail(function (xhr) {
                notify('danger', failMessage(xhr));
            }).always(function () {
                $button.prop('disabled', false);
            });
        });

        $('.mks-sales-track-settings-menu').on('click', '.mks-sales-track-settings-menu-item', function () {
            var section = this.getAttribute('data-section');

            $(this).addClass('is-active').attr('aria-selected', 'true')
                .siblings().removeClass('is-active').attr('aria-selected', 'false');
            $('.mks-sales-track-settings-panel').addClass('mks-sales-track-is-hidden')
                .filter('[data-section="' + section + '"]').removeClass('mks-sales-track-is-hidden');
            $('#mks-sales-track-section').val(section);

            if (window.history && window.history.replaceState) {
                window.history.replaceState(null, '', '?section=' + encodeURIComponent(section));
            }
        });
    }

    /* ---------------------------------------------------------------------
     * Start
     * ------------------------------------------------------------------ */

    function start() {
        bindCopy();

        bindDial();

        if (cfg.pitch) {
            bindPitches(cfg.page === 'list' ? function () {
                $('table.table-mks-sales-track-events').DataTable().ajax.reload(null, false);
            } : function () {
                window.setTimeout(function () {
                    window.location.reload();
                }, 500);
            });
        }

        if (cfg.page === 'lists') {
            initLists();
        }

        if (cfg.page === 'list') {
            initList();
            bindAi(function () {
                $('table.table-mks-sales-track-events').DataTable().ajax.reload(null, false);
            });
            bindOutcomes(function () {
                $('table.table-mks-sales-track-events').DataTable().ajax.reload(null, false);
            });
        } else if (cfg.page === 'follow_ups') {
            bindOutcomes(function () {
                window.setTimeout(function () {
                    window.location.reload();
                }, 500);
            });
        } else if (cfg.page === 'queue') {
            initQueue();
        } else if (cfg.page === 'devices') {
            initDevices();
        } else if (cfg.page === 'device') {
            initDevice();
        } else if (cfg.page === 'settings') {
            initSettings();
        } else if (cfg.page === 'dashboard' || cfg.page === 'reports') {
            // The dashboard is a plain GET page: changing a filter reloads it,
            // so every view has its own address to share or bookmark.
            $('.mks-sales-track-autosubmit').on('change', function () {
                this.form.submit();
            });
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }
})();
