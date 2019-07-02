cc.Class({
    extends: cc.Component,

    properties: {
        winAudio: {
            default: null,
            type: cc.AudioClip
        },

        loseAudio: {
            default: null,
            type: cc.AudioClip
        },

        cardAudio: {
            default: null,
            type: cc.AudioClip
        },

        playAudio: {
            default: null,
            type: cc.AudioClip
        },

        excitingAudio: {
            default: null,
            type: cc.AudioClip
        },

        bgm: {
            default: null,
            type: cc.AudioClip
        }
    },

    playMusic: function() {
        cc.audioEngine.playMusic( this.bgm, true );
    },

    pauseMusic: function() {
        cc.audioEngine.pauseMusic();
    },

    stopMusic: function() {
        cc.audioEngine.stopMusic();
    },

    resumeMusic: function() {
        cc.audioEngine.resumeMusic();
    },

    _playSFX: function(clip) {
        cc.audioEngine.playEffect( clip, false );
    },

    playWin: function() {
        this._playSFX(this.winAudio);
    },

    playLose: function() {
        this._playSFX(this.loseAudio);
    },

    playCard: function() {
        this._playSFX(this.cardAudio);
    },

    playNormal: function() {
        cc.audioEngine.playMusic(this.playAudio, true);
    },

    playExciting: function() {
        cc.audioEngine.playMusic(this.excitingAudio, true);
    }
});
