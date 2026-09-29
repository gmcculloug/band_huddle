// Band Huddle Gig Mode JavaScript
// Handles offline caching, UI interactions, and performance optimizations

class GigMode {
    constructor() {
        this.gigData = null;
        this.currentSet = 1;
        this.currentSong = null;
        this.songs = [];
        this.isOnline = navigator.onLine;
        this.serviceWorker = null;
        this.wakeLock = null;
        this.touchStartX = null;
        this.touchStartY = null;
        this.swipeThreshold = 100;

        // Auto-scroll properties
        this.autoScrollEnabled = false;
        this.autoScrollInterval = null;
        this.autoScrollAnimationId = null;
        this.scrollAccumulator = 0; // Accumulate small scroll amounts

        // Generate speed options from 0.1x to 2x in 0.05x increments
        this.scrollSpeedOptions = [];
        for (let i = 0.1; i <= 2.0; i += 0.05) {
            this.scrollSpeedOptions.push(Math.round(i * 100) / 100); // Round to avoid floating point precision
        }

        this.currentSpeedIndex = 18; // Default to 1.0x (index 18)
        this.autoScrollSpeed = this.scrollSpeedOptions[this.currentSpeedIndex];

        // Font size properties
        this.fontSizeOptions = ['xs', 'sm', 'md', 'lg', 'xl', '2xl', '3xl'];
        this.currentFontSizeIndex = 2; // Default to 'md' (index 2)

        this.init();
    }

    async init() {
        try {
            this.updateLoadingStatus('Initializing app...');
            await this.registerServiceWorker();

            this.updateLoadingStatus('Loading gig data...');
            await this.loadGigData();

            this.updateLoadingStatus('Setting up interface...');
            this.setupEventListeners();
            this.setupSettings();
            this.checkOnlineStatus();

            this.updateLoadingStatus('Ready!');
            setTimeout(() => this.hideLoading(), 500);

        } catch (error) {
            console.error('Failed to initialize gig mode:', error);
            this.showError('Failed to initialize gig mode: ' + error.message);
        }
    }

    updateLoadingStatus(message) {
        const statusEl = document.getElementById('loading-status');
        if (statusEl) {
            statusEl.textContent = message;
        }
    }

    hideLoading() {
        const loadingScreen = document.getElementById('loading-screen');
        const app = document.getElementById('app');

        if (loadingScreen && app) {
            loadingScreen.classList.add('hidden');
            app.classList.remove('hidden');
        }
    }

    showError(message) {
        const errorEl = document.getElementById('error-message');
        const errorText = document.getElementById('error-text');
        const loadingScreen = document.getElementById('loading-screen');

        if (errorEl && errorText) {
            errorText.textContent = message;
            errorEl.classList.remove('hidden');
            if (loadingScreen) {
                loadingScreen.classList.add('hidden');
            }
        }
    }

    async registerServiceWorker() {
        if ('serviceWorker' in navigator) {
            try {
                const registration = await navigator.serviceWorker.register('/service-worker.js');
                this.serviceWorker = registration;

                // Listen for messages from service worker
                navigator.serviceWorker.addEventListener('message', (event) => {
                    this.handleServiceWorkerMessage(event.data);
                });

            } catch (error) {
                console.warn('Service Worker registration failed:', error);
            }
        }
    }

    handleServiceWorkerMessage(data) {
        switch (data.type) {
            case 'GIG_DATA_UPDATED':
                this.showNotification('Gig data updated!');
                break;
            case 'GIG_CACHED':
                this.updateCacheStatus();
                this.showNotification('Gig cached for offline use!');
                break;
            case 'GIG_CACHE_ERROR':
                this.showNotification('Failed to cache gig data', 'error');
                break;
        }
    }

    async loadGigData() {
        const gigId = window.GIG_DATA?.id;
        if (!gigId) {
            throw new Error('No gig ID provided');
        }

        try {
            const response = await fetch(`/api/gigs/${gigId}/gig_mode`);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            this.gigData = await response.json();
            this.processGigData();
            this.renderSetNavigation();
            this.renderSongList();

        } catch (error) {
            // Try to load from cache if network fails
            if (!this.isOnline && 'caches' in window) {
                try {
                    const cache = await caches.open('band-huddle-gig-data-v1');
                    const cachedResponse = await cache.match(`/api/gigs/${gigId}/gig_mode`);

                    if (cachedResponse) {
                        this.gigData = await cachedResponse.json();
                        this.processGigData();
                        this.renderSetNavigation();
                        this.renderSongList();
                        this.showNotification('Loaded from offline cache', 'warning');
                        return;
                    }
                } catch (cacheError) {
                    console.error('Failed to load from cache:', cacheError);
                }
            }

            throw error;
        }
    }

    processGigData() {
        if (!this.gigData) return;

        // Flatten songs from all sets for easier navigation
        this.songs = [];
        const setNumbers = Object.keys(this.gigData.sets).map(Number).sort();

        setNumbers.forEach(setNumber => {
            const setData = this.gigData.sets[setNumber];
            setData.songs.forEach((song, index) => {
                this.songs.push({
                    ...song,
                    setNumber: setNumber
                });
            });
        });

        // Set default current set to first available set
        if (setNumbers.length > 0) {
            this.currentSet = setNumbers[0];
        }
    }

    renderSetNavigation() {
        const setNav = document.getElementById('set-nav');
        if (!setNav || !this.gigData) return;

        const setNumbers = Object.keys(this.gigData.sets).map(Number).sort();

        setNav.innerHTML = setNumbers.map(setNumber => {
            const setData = this.gigData.sets[setNumber];
            return `
                <button class="set-tab ${setNumber === this.currentSet ? 'active' : ''}"
                        data-set="${setNumber}">
                    Set ${setNumber} (${setData.song_count})
                </button>
            `;
        }).join('');

        // Add event listeners for set tabs
        setNav.querySelectorAll('.set-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                this.switchToSet(parseInt(tab.dataset.set));
            });
        });
    }

    renderSongList() {
        const songList = document.getElementById('song-list');
        if (!songList || !this.gigData) return;

        const setData = this.gigData.sets[this.currentSet];
        if (!setData) return;

        songList.innerHTML = setData.songs.map((song, index) => {
            // Check for incoming transition (from previous song)
            const hasIncoming = index > 0 && setData.songs[index - 1].transition_data?.has_transition;

            // Check for outgoing transition (to next song)
            const hasOutgoing = song.transition_data?.has_transition && index < setData.songs.length - 1;

            const incomingArrow = hasIncoming ? '<span class="transition-arrow incoming active" title="incoming transition" style="color: #3b82f6 !important; font-weight: bold; font-size: 1.2em;">➔</span> ' : '';
            const outgoingArrow = hasOutgoing ? ' <span class="transition-arrow outgoing active" title="transition" style="color: #3b82f6 !important; font-weight: bold; font-size: 1.2em;">➔</span>' : '';

            // Practice state styling and badge
            const isPractice = song.practice_state || false;
            const practiceClass = isPractice ? ' practice-song' : '';
            const practiceBadge = isPractice ? '<span class="practice-badge">🎯</span>' : '';

            return `
            <div class="song-item${practiceClass}" data-song-id="${song.id}" data-position="${index}">
                <div class="song-header">
                    <h3 class="song-title">
                        <span class="song-count">${song.position}.</span>
                        ${incomingArrow}${practiceBadge}${this.displaySongTitle(song.title)}${outgoingArrow}
                    </h3>
                    <div class="song-meta">
                        <div class="song-key">${this.escapeHtml(song.key || 'N/A')}</div>
                        ${song.tempo ? '<span>' + song.tempo + ' BPM</span>' : ''}
                        ${song.duration ? '<span>' + song.duration + '</span>' : ''}
                    </div>
                </div>
                ${song.notes ? '<div class="song-notes">' + this.escapeHtml(song.notes) + '</div>' : ''}
            </div>
        `;
        }).join('');

        // Add event listeners for song items
        songList.querySelectorAll('.song-item').forEach(item => {
            item.addEventListener('click', () => {
                const position = parseInt(item.dataset.position);
                this.openSongModal(setData.songs[position]);
            });
        });
    }

    switchToSet(setNumber) {
        this.currentSet = setNumber;

        // Update active tab
        document.querySelectorAll('.set-tab').forEach(tab => {
            tab.classList.toggle('active', parseInt(tab.dataset.set) === setNumber);
        });

        // Re-render song list
        this.renderSongList();
    }

    openSongModal(song) {
        this.currentSong = song;

        // Populate modal content
        document.getElementById('song-title').innerHTML = this.displaySongTitle(song.title);

        // Build combined content with stats, notes, and lyrics
        let content = '';

        // Add song stats
        const stats = [];
        if (song.key) stats.push(`Key: ${song.key}`);
        if (song.tempo) stats.push(`Tempo: ${song.tempo} BPM`);
        if (song.duration) stats.push(`Duration: ${song.duration}`);

        if (stats.length > 0) {
            content += stats.join(' | ') + '\n';
        }

        // Add notes if available
        if (song.notes && song.notes.trim()) {
            content += 'Notes: ' + song.notes + '\n';
        }

        // Add separator if we have stats or notes
        if (content.length > 0) {
            content += '─'.repeat(40) + '\n';
        }

        // Add lyrics
        content += song.lyrics || 'No lyrics available';

        const contentEl = document.getElementById('song-content');
        contentEl.textContent = content;

        // Update navigation buttons - use current set position
        const setPosition = this.getCurrentSetSongPosition();
        const setTotalSongs = this.getCurrentSetTotalSongs();

        document.getElementById('current-position-header').textContent = setPosition;
        document.getElementById('total-songs-header').textContent = setTotalSongs;

        const globalIndex = this.getCurrentSongIndex();
        const globalTotal = this.songs.length;
        document.getElementById('prev-song').disabled = globalIndex === 0;
        document.getElementById('next-song').disabled = globalIndex === globalTotal - 1;

        // Initialize auto-scroll controls
        this.updateScrollSpeedDisplay();
        this.updateAutoScrollButton();

        // Initialize font size controls
        this.updateFontSize();

        // Show modal
        const modal = document.getElementById('song-modal');
        modal.classList.add('open');

        // Prevent body scroll
        document.body.style.overflow = 'hidden';

        // Defensive footer visibility validation
        setTimeout(() => {
            const footer = document.getElementById('song-modal').querySelector('.modal-footer');
            const footerRect = footer.getBoundingClientRect();
            if (footerRect.bottom > window.innerHeight || footerRect.top < 0) {
                console.warn('Footer not visible, forcing layout recalculation');
                footer.style.position = 'relative';
                footer.style.zIndex = '1000';
            }
        }, 100);
    }

    closeSongModal() {
        const modal = document.getElementById('song-modal');
        modal.classList.remove('open');
        document.body.style.overflow = '';

        // Stop auto-scroll when closing modal
        this.autoScrollEnabled = false;
        this.stopAutoScroll();

        this.currentSong = null;
    }

    getCurrentSongIndex() {
        if (!this.currentSong) return -1;
        return this.songs.findIndex(song => song.id === this.currentSong.id);
    }

    getCurrentSetSongPosition() {
        if (!this.currentSong || !this.gigData) return 1;

        const setData = this.gigData.sets[this.currentSet];
        if (!setData) return 1;

        const songIndex = setData.songs.findIndex(song => song.id === this.currentSong.id);
        return songIndex >= 0 ? songIndex + 1 : 1;
    }

    getCurrentSetTotalSongs() {
        if (!this.gigData) return 1;

        const setData = this.gigData.sets[this.currentSet];
        return setData ? setData.songs.length : 1;
    }

    navigateToSong(direction) {
        const currentIndex = this.getCurrentSongIndex();
        let newIndex;

        if (direction === 'prev') {
            newIndex = Math.max(0, currentIndex - 1);
        } else {
            newIndex = Math.min(this.songs.length - 1, currentIndex + 1);
        }

        if (newIndex !== currentIndex) {
            const newSong = this.songs[newIndex];

            // Switch sets if necessary
            if (newSong.setNumber !== this.currentSet) {
                this.switchToSet(newSong.setNumber);
            }

            this.openSongModal(newSong);
        }
    }

    setupEventListeners() {
        // Back button
        document.getElementById('back-btn').addEventListener('click', () => {
            if (confirm('Exit gig mode and return to gig page?')) {
                window.location.href = `/gigs/${window.GIG_DATA.id}`;
            }
        });

        // Menu button
        document.getElementById('menu-btn').addEventListener('click', () => {
            document.getElementById('menu-overlay').classList.add('open');
        });

        // Close menu
        document.getElementById('close-menu').addEventListener('click', () => {
            document.getElementById('menu-overlay').classList.remove('open');
        });

        // Menu overlay click-to-close
        document.getElementById('menu-overlay').addEventListener('click', (e) => {
            if (e.target.id === 'menu-overlay') {
                document.getElementById('menu-overlay').classList.remove('open');
            }
        });

        // Modal controls
        document.getElementById('close-modal').addEventListener('click', () => {
            this.closeSongModal();
        });

        document.getElementById('prev-song').addEventListener('click', () => {
            this.navigateToSong('prev');
        });

        document.getElementById('next-song').addEventListener('click', () => {
            this.navigateToSong('next');
        });

        // Auto-scroll controls
        document.getElementById('auto-scroll-toggle').addEventListener('click', () => {
            this.toggleAutoScroll();
        });

        document.getElementById('scroll-speed-down').addEventListener('click', () => {
            this.decreaseScrollSpeed();
        });

        document.getElementById('scroll-speed-up').addEventListener('click', () => {
            this.increaseScrollSpeed();
        });

        // Font size controls
        document.getElementById('font-size-down').addEventListener('click', () => {
            this.decreaseFontSize();
        });

        document.getElementById('font-size-up').addEventListener('click', () => {
            this.increaseFontSize();
        });

        // Pause auto-scroll on manual interaction with lyrics
        document.addEventListener('click', (e) => {
            if (e.target.closest('#song-content') && this.autoScrollEnabled) {
                this.autoScrollEnabled = false;
                this.stopAutoScroll();
                this.updateAutoScrollButton();
            }
        });

        // Modal overlay click-to-close
        document.getElementById('song-modal').addEventListener('click', (e) => {
            if (e.target.id === 'song-modal') {
                this.closeSongModal();
            }
        });

        // Error retry button
        document.getElementById('retry-btn').addEventListener('click', () => {
            window.location.reload();
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (this.currentSong) {
                switch (e.key) {
                    case 'ArrowLeft':
                        e.preventDefault();
                        this.navigateToSong('prev');
                        break;
                    case 'ArrowRight':
                        e.preventDefault();
                        this.navigateToSong('next');
                        break;
                    case 'Escape':
                        e.preventDefault();
                        this.closeSongModal();
                        break;
                }
            }
        });

        // Touch/swipe navigation
        this.setupTouchNavigation();

        // Online/offline detection
        window.addEventListener('online', () => {
            this.isOnline = true;
            this.updateOnlineStatus();
        });

        window.addEventListener('offline', () => {
            this.isOnline = false;
            this.updateOnlineStatus();
        });

        // Settings controls
        this.setupSettingsControls();
    }

    setupTouchNavigation() {
        const modal = document.getElementById('song-modal');

        modal.addEventListener('touchstart', (e) => {
            if (e.touches.length === 1) {
                this.touchStartX = e.touches[0].clientX;
                this.touchStartY = e.touches[0].clientY;
            }
        });

        modal.addEventListener('touchend', (e) => {
            if (!this.touchStartX || !this.touchStartY) return;

            const touchEndX = e.changedTouches[0].clientX;
            const touchEndY = e.changedTouches[0].clientY;

            const deltaX = touchEndX - this.touchStartX;
            const deltaY = touchEndY - this.touchStartY;

            // Only process horizontal swipes
            if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > this.swipeThreshold) {
                if (deltaX > 0) {
                    // Swipe right - previous song
                    this.navigateToSong('prev');
                    this.showSwipeIndicator('left');
                } else {
                    // Swipe left - next song
                    this.navigateToSong('next');
                    this.showSwipeIndicator('right');
                }
            }

            this.touchStartX = null;
            this.touchStartY = null;
        });
    }

    showSwipeIndicator(direction) {
        const indicators = document.getElementById('touch-indicators');
        indicators.classList.add('show');

        setTimeout(() => {
            indicators.classList.remove('show');
        }, 1500);
    }

    setupSettingsControls() {
        // Theme selector
        const themeSelect = document.getElementById('theme-select');
        themeSelect.addEventListener('change', (e) => {
            this.changeTheme(e.target.value);
            this.saveSettings();
        });

        // Font size selector
        const fontSizeSelect = document.getElementById('font-size-select');
        fontSizeSelect.addEventListener('change', (e) => {
            this.changeFontSize(e.target.value);
            this.saveSettings();
        });

        // Keep screen on
        const keepScreenOn = document.getElementById('keep-screen-on');
        keepScreenOn.addEventListener('change', (e) => {
            this.toggleScreenWakeLock(e.target.checked);
            this.saveSettings();
        });

        // Cache gig button
        document.getElementById('cache-gig').addEventListener('click', () => {
            this.cacheGigForOffline();
        });
    }

    setupSettings() {
        // Load saved settings
        const settings = this.loadSettings();

        // Apply theme
        this.changeTheme(settings.theme);
        document.getElementById('theme-select').value = settings.theme;

        // Apply font size
        this.changeFontSize(settings.fontSize);
        document.getElementById('font-size-select').value = settings.fontSize;

        // Apply screen wake lock
        if (settings.keepScreenOn) {
            this.toggleScreenWakeLock(true);
            document.getElementById('keep-screen-on').checked = true;
        }

        // Update cache status
        this.updateCacheStatus();
    }

    changeTheme(theme) {
        const body = document.body;
        body.className = body.className.replace(/theme-\w+/g, '');
        body.classList.add(`theme-${theme}`);
    }

    changeFontSize(size) {
        const body = document.body;
        body.className = body.className.replace(/font-\w+/g, '');
        body.classList.add(`font-${size}`);
    }

    async toggleScreenWakeLock(enable) {
        if ('wakeLock' in navigator) {
            try {
                if (enable && !this.wakeLock) {
                    this.wakeLock = await navigator.wakeLock.request('screen');
                } else if (!enable && this.wakeLock) {
                    await this.wakeLock.release();
                    this.wakeLock = null;
                }
            } catch (error) {
                console.warn('Wake lock failed:', error);
            }
        }
    }

    async cacheGigForOffline() {
        if (!this.serviceWorker) {
            this.showNotification('Service Worker not available', 'error');
            return;
        }

        const button = document.getElementById('cache-gig');
        const originalText = button.innerHTML;
        button.innerHTML = '<div class="loading-spinner"></div> Caching...';
        button.disabled = true;

        try {
            // Send message to service worker to cache gig data
            navigator.serviceWorker.controller?.postMessage({
                type: 'CACHE_GIG_DATA',
                gigId: window.GIG_DATA.id
            });

            // The service worker will notify us when caching is complete
            setTimeout(() => {
                button.innerHTML = originalText;
                button.disabled = false;
            }, 3000);

        } catch (error) {
            console.error('Failed to cache gig:', error);
            this.showNotification('Failed to cache gig data', 'error');
            button.innerHTML = originalText;
            button.disabled = false;
        }
    }

    async updateCacheStatus() {
        if (!this.serviceWorker) return;

        try {
            const messageChannel = new MessageChannel();

            messageChannel.port1.onmessage = (event) => {
                const status = event.data;
                const statusEl = document.getElementById('offline-status');

                if (status.fullyCached) {
                    statusEl.textContent = 'Yes ✓';
                    statusEl.className = 'status-value success';
                } else {
                    statusEl.textContent = 'No';
                    statusEl.className = 'status-value';
                }
            };

            navigator.serviceWorker.controller?.postMessage({
                type: 'GET_CACHE_STATUS',
                gigId: window.GIG_DATA.id
            }, [messageChannel.port2]);

        } catch (error) {
            console.error('Failed to check cache status:', error);
        }
    }

    updateOnlineStatus() {
        const statusIndicator = document.getElementById('status-indicator');

        if (this.isOnline) {
            statusIndicator.className = 'status-indicator online';
        } else {
            statusIndicator.className = 'status-indicator offline';
        }
    }

    checkOnlineStatus() {
        this.updateOnlineStatus();

        // Check periodically
        setInterval(() => {
            this.updateOnlineStatus();
        }, 5000);
    }

    showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;

        // Style the notification
        Object.assign(notification.style, {
            position: 'fixed',
            top: '20px',
            right: '20px',
            background: type === 'error' ? 'var(--error-color)' :
                       type === 'warning' ? 'var(--warning-color)' : 'var(--success-color)',
            color: 'white',
            padding: '1rem 1.5rem',
            borderRadius: '8px',
            zIndex: '9999',
            fontSize: 'calc(0.9rem * var(--font-size-multiplier))',
            boxShadow: 'var(--shadow)',
            transform: 'translateX(100%)',
            transition: 'transform 0.3s ease',
            maxWidth: '300px',
            wordWrap: 'break-word'
        });

        document.body.appendChild(notification);

        // Animate in
        setTimeout(() => {
            notification.style.transform = 'translateX(0)';
        }, 100);

        // Remove after delay
        setTimeout(() => {
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        }, 4000);
    }

    loadSettings() {
        try {
            const saved = localStorage.getItem('gigMode.settings');
            return saved ? JSON.parse(saved) : this.getDefaultSettings();
        } catch (error) {
            console.warn('Failed to load settings:', error);
            return this.getDefaultSettings();
        }
    }

    saveSettings() {
        try {
            const settings = {
                theme: document.getElementById('theme-select').value,
                fontSize: document.getElementById('font-size-select').value,
                keepScreenOn: document.getElementById('keep-screen-on').checked
            };

            localStorage.setItem('gigMode.settings', JSON.stringify(settings));
        } catch (error) {
            console.warn('Failed to save settings:', error);
        }
    }

    getDefaultSettings() {
        return {
            theme: 'dark',
            fontSize: 'large',
            keepScreenOn: true
        };
    }

    escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    displaySongTitle(title) {
        const marker = '\u0000';
        let markedTitle = String(title || '')
            .replace(/(?:https?:\/\/|www\.)[^\s<>]+|(?:[\w-]+\.)+[a-z]{2,}(?:\/[^\s<>]*)?/gi, url =>
                url.replace(/[.:\/?&=#-]/g, character => character + marker)
            )
            .replace(/(\d)([-/])(?=\d)/g, `$1$2${marker}`);
        return this.escapeHtml(markedTitle).split(marker).join('<wbr>');
    }

    // Auto-scroll functionality
    toggleAutoScroll() {
        this.autoScrollEnabled = !this.autoScrollEnabled;

        if (this.autoScrollEnabled) {
            this.startAutoScroll();
        } else {
            this.stopAutoScroll();
        }

        this.updateAutoScrollButton();
    }

    startAutoScroll() {
        this.stopAutoScroll(); // Clear any existing animation

        const contentEl = document.getElementById('song-content');
        if (!contentEl) return;

        // Check if content is scrollable
        if (contentEl.scrollHeight <= contentEl.clientHeight) {
            return;
        }

        // Reset accumulator
        this.scrollAccumulator = 0;

        // Calculate smooth scroll speed - convert from interval-based to pixels per second
        // Original: 1 pixel every (50ms / speed), so pixels per second = speed * (1000/50) = speed * 20
        const pixelsPerSecond = this.autoScrollSpeed * 20;
        let lastFrameTime = performance.now();

        const animateScroll = (currentTime) => {
            if (!this.autoScrollEnabled) return;

            const deltaTime = currentTime - lastFrameTime;
            const scrollAmount = (deltaTime / 1000) * pixelsPerSecond;

            // Accumulate small scroll amounts
            this.scrollAccumulator += scrollAmount;

            const currentScroll = contentEl.scrollTop;
            const maxScroll = contentEl.scrollHeight - contentEl.clientHeight;

            if (currentScroll >= maxScroll) {
                // Reached the end, stop auto-scroll
                this.autoScrollEnabled = false;
                this.stopAutoScroll();
                this.updateAutoScrollButton();
            } else {
                // Apply scroll when we have at least 0.5 pixels accumulated
                if (this.scrollAccumulator >= 0.5) {
                    const pixelsToScroll = Math.floor(this.scrollAccumulator);
                    contentEl.scrollTop += pixelsToScroll;
                    this.scrollAccumulator -= pixelsToScroll;
                }

                lastFrameTime = currentTime;
                this.autoScrollAnimationId = requestAnimationFrame(animateScroll);
            }
        };

        this.autoScrollAnimationId = requestAnimationFrame(animateScroll);
    }

    stopAutoScroll() {
        // Clear animation frame
        if (this.autoScrollAnimationId) {
            cancelAnimationFrame(this.autoScrollAnimationId);
            this.autoScrollAnimationId = null;
        }

        // Clear interval (for backwards compatibility)
        if (this.autoScrollInterval) {
            clearInterval(this.autoScrollInterval);
            this.autoScrollInterval = null;
        }

        // Reset accumulator
        this.scrollAccumulator = 0;
    }

    increaseScrollSpeed() {
        if (this.currentSpeedIndex < this.scrollSpeedOptions.length - 1) {
            this.currentSpeedIndex++;
            this.autoScrollSpeed = this.scrollSpeedOptions[this.currentSpeedIndex];
            this.updateScrollSpeedDisplay();

            // Restart auto-scroll if it's currently running
            if (this.autoScrollEnabled) {
                this.startAutoScroll();
            }
        }
    }

    decreaseScrollSpeed() {
        if (this.currentSpeedIndex > 0) {
            this.currentSpeedIndex--;
            this.autoScrollSpeed = this.scrollSpeedOptions[this.currentSpeedIndex];
            this.updateScrollSpeedDisplay();

            // Restart auto-scroll if it's currently running
            if (this.autoScrollEnabled) {
                this.startAutoScroll();
            }
        }
    }

    updateScrollSpeedDisplay() {
        const speedText = document.getElementById('scroll-speed-text');
        if (speedText) {
            speedText.textContent = `${this.autoScrollSpeed}x`;
        }

        // Update button states
        const speedDownBtn = document.getElementById('scroll-speed-down');
        const speedUpBtn = document.getElementById('scroll-speed-up');

        if (speedDownBtn) {
            speedDownBtn.disabled = this.currentSpeedIndex === 0;
        }
        if (speedUpBtn) {
            speedUpBtn.disabled = this.currentSpeedIndex === this.scrollSpeedOptions.length - 1;
        }
    }

    updateAutoScrollButton() {
        const toggleBtn = document.getElementById('auto-scroll-toggle');
        if (toggleBtn) {
            if (this.autoScrollEnabled) {
                toggleBtn.classList.add('active');
                toggleBtn.innerHTML = `
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="6" y="4" width="4" height="16"></rect>
                        <rect x="14" y="4" width="4" height="16"></rect>
                    </svg>
                `;
                toggleBtn.title = 'Pause auto-scroll';
            } else {
                toggleBtn.classList.remove('active');
                toggleBtn.innerHTML = `
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polygon points="5,3 19,12 5,21"></polygon>
                    </svg>
                `;
                toggleBtn.title = 'Start auto-scroll';
            }
        }
    }

    // Font size functionality
    increaseFontSize() {
        if (this.currentFontSizeIndex < this.fontSizeOptions.length - 1) {
            this.currentFontSizeIndex++;
            this.updateFontSize();
        }
    }

    decreaseFontSize() {
        if (this.currentFontSizeIndex > 0) {
            this.currentFontSizeIndex--;
            this.updateFontSize();
        }
    }

    updateFontSize() {
        const contentEl = document.getElementById('song-content');
        if (contentEl) {
            // Remove all existing font size classes
            this.fontSizeOptions.forEach(size => {
                contentEl.classList.remove(`font-${size}`);
            });

            // Add the current font size class
            const currentSize = this.fontSizeOptions[this.currentFontSizeIndex];
            contentEl.classList.add(`font-${currentSize}`);
        }

        // Update button states
        const fontSizeDownBtn = document.getElementById('font-size-down');
        const fontSizeUpBtn = document.getElementById('font-size-up');

        if (fontSizeDownBtn) {
            fontSizeDownBtn.disabled = this.currentFontSizeIndex === 0;
        }
        if (fontSizeUpBtn) {
            fontSizeUpBtn.disabled = this.currentFontSizeIndex === this.fontSizeOptions.length - 1;
        }
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new GigMode();
});

// Handle visibility change to maintain wake lock
document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
        // Re-request wake lock if needed
        const keepScreenOn = document.getElementById('keep-screen-on');
        if (keepScreenOn && keepScreenOn.checked) {
            window.gigMode?.toggleScreenWakeLock(true);
        }
    }
});

window.gigMode = null;
document.addEventListener('DOMContentLoaded', () => {
    window.gigMode = new GigMode();
});
