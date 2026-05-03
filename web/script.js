'use strict';

if (typeof GetParentResourceName === 'undefined') { 
    window.GetParentResourceName = function () { 
        return 'gov'; 
    }; 
}


$(window).on('load', function () { 
    nui('nuiLoaded'); 
});


function nui(eventName, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${eventName}`, {
        method: 'POST', 
        headers: { 
            'Content-Type': 'application/json' 
        }, 
        body: JSON.stringify(data)
    })
    .then(res => res.json())
    .catch(err => {
        console.log(`[Erro] ${eventName}:`, err);
    });
}

let currentUser = {};
let currentVehicles = []; 
let currentProperties = []; 

window.addEventListener('message', (event) => {
    let item = event.data;
    if (item.action === "setupData") {
        setupData(item);
    }
});

function setupData(data) {
    currentUser = data;
    
    $('#user-id').val(data.passport);
    $('#welcome-id').text(data.passport);
    $('#welcome-name').text(data.name);
    
    $('.doc-name').text(data.name); 
    $('.doc-id').text(data.passport);

    // Lógica para primeiro acesso vs usuário com conta
    if (data.status === 'sem_conta') {
        $('#auth-main-text').text("Crie sua senha de acesso gov.xp:");
        $('#login-fields').hide();
        $('#register-fields').show();
    } else {
        $('#auth-main-text').text("Identifique-se no gov.xp com:");
        $('#register-fields').hide();
        $('#login-fields').show();
    }

    // Lógica da ANAC: Se ele for piloto, mostrar o Brevê
    if (data.anac) {
        $('#anac-id-text').text(data.anac.anac_id);
        $('#anac-hours-text').text(data.anac.horas + "h");
        $('#anac-rep-text').text(data.anac.reputacao + "%");
        $('#anac-card').show();
    } else {
        $('#anac-card').hide();
    }
}

// Função para transitar entre telas
function switchScreen(screenId) {
    $('.crlv-overlay').hide();
    $('.screen').removeClass('active');
    $(`#${screenId}`).addClass('active');
}

// ============================================================
// NAVEGAÇÃO BÁSICA
// ============================================================
$('.btn-back').click(function() {
    switchScreen('screen-dash');
});

$('#btn-logout').click(function() { 
    $('#user-pass').val(''); 
    switchScreen('screen-auth'); 
});

// ============================================================
// LÓGICA DE LOGIN
// ============================================================
$('#btn-login').click(function() {
    const pass = $('#user-pass').val();
    
    if (!pass) {
        $('#auth-error').text('Digite a senha.');
        return;
    }

    nui('login', { pass: pass }).then(res => {
        if (res && res.success) { 
            $('#auth-error').text(''); 
            switchScreen('screen-dash'); 
        } else { 
            $('#auth-error').text(res.error || 'Senha incorreta.'); 
        }
    });
});

// ============================================================
// LÓGICA DE REGISTRO
// ============================================================
$('#btn-register').click(function() {
    const pass = $('#reg-pass').val();
    const confirm = $('#reg-confirm').val();

    if (pass.length < 4) {
        $('#auth-error').text('A senha deve ter no mínimo 4 caracteres.');
        return;
    }

    if (pass !== confirm) {
        $('#auth-error').text('As senhas não coincidem!');
        return;
    }

    nui('register', { pass: pass }).then(res => {
        if (res && res.success) {
            $('#auth-error').text('');
            switchScreen('screen-dash');
        } else {
            $('#auth-error').text('Erro ao criar conta.');
        }
    });
});

// ============================================================
// EVENTOS DO MENU DASHBOARD
// ============================================================
$('.menu-item').click(function() {
    const targetScreen = $(this).data('target');
    
    if (targetScreen === 'screen-vehicles') {
        loadVehicles();
    } else if (targetScreen === 'screen-properties') {
        loadProperties();
    } else {
        switchScreen(targetScreen);
    }
});

// ============================================================
// LÓGICA DOS VEÍCULOS E SISTEMA DE ROUBO COM TIMER
// ============================================================
function loadVehicles() {
    nui('getVehicles').then(data => {
        const list = $('#vehicle-list');
        list.empty();
        
        currentVehicles = data || []; 

        if (data && data.length > 0) {
            data.forEach((v, index) => {
                
                let statusHtml = "";
                if (v.expired) {
                    statusHtml = `<span class="status-badge status-bad">IPVA ATRASADO</span>`;
                } else {
                    statusHtml = `<span class="status-badge status-ok">IPVA EM DIA</span>`;
                }
                
                let theftHtml = "";
                if (v.isStolen) {
                    theftHtml = `
                        <button class="btn-action btn-show-bo" data-index="${index}" style="border-color:#37474f; color:#37474f;">
                            📄 Exibir Boletim
                        </button>
                        <button class="btn-action btn-rem-stolen" data-plate="${v.plate}" style="border-color:var(--success); color:var(--success);">
                            ✅ Retirar Queixa
                        </button>
                    `;
                } else {
                    theftHtml = `
                        <button class="btn-action btn-rep-stolen" data-plate="${v.plate}" data-model="${v.model}" style="border-color:var(--danger); color:var(--danger);">
                            🚨 Informar Roubo/Furto
                        </button>
                    `;
                }

                let expiredClass = "";
                if (v.expired) {
                    expiredClass = "expired";
                }

                list.append(`
                    <div class="vehicle-card ${expiredClass}">
                        <div class="card-header">
                            <div>
                                <div class="card-title">${v.model.toUpperCase()}</div>
                                <div class="card-subtitle">PLACA: ${v.plate}</div>
                            </div>
                            ${statusHtml}
                        </div>
                        
                        <div class="card-details">
                            <p><strong>Vencimento IPVA:</strong> ${v.days} dias</p>
                        </div>
                        
                        <div style="display:flex; flex-direction: column; gap: 8px; margin-top: 10px;">
                            <button class="btn-action btn-expand-veh" data-index="${index}">Ver CRLV Digital</button>
                            ${theftHtml}
                        </div>
                    </div>
                `);
            });

            // Listeners da Lista de Veículos
            $('.btn-expand-veh').click(function() { 
                openCRLV($(this).data('index')); 
            });
            
            $('.btn-show-bo').click(function() { 
                openBO($(this).data('index')); 
            });
            
            // Simulação de Aprovação para Reportar Roubo
            $('.btn-rep-stolen').click(function() {
                const plate = $(this).data('plate');
                const model = $(this).data('model');
                
                $('#loader-text').text("Registrando ocorrência policial...");
                $('#loading-overlay').fadeIn(300);

                setTimeout(() => {
                    nui('reportStolen', { plate: plate, model: model }).then(() => {
                        $('#loading-overlay').fadeOut(300);
                        loadVehicles();
                    });
                }, 5000); // 5 segundos de espera
            });

            // Simulação de Aprovação para Remover Queixa
            $('.btn-rem-stolen').click(function() {
                const plate = $(this).data('plate');
                
                $('#loader-text').text("Verificando protocolo de baixa...");
                $('#loading-overlay').fadeIn(300);

                setTimeout(() => {
                    nui('removeStolen', { plate: plate }).then(() => {
                        $('#loading-overlay').fadeOut(300);
                        loadVehicles();
                    });
                }, 5000); 
            });

        } else {
            list.html('<div class="empty-state">Nenhum veículo encontrado.</div>');
        }
        
        switchScreen('screen-vehicles');
    });
}

function openCRLV(index) {
    const v = currentVehicles[index];
    if (!v) return;
    
    $('#crlv-plate').text(v.plate.toUpperCase());
    $('#crlv-model').text(v.model.toUpperCase());
    
    $('#crlv-viewer').fadeIn(200);
}

function openBO(index) {
    const v = currentVehicles[index];
    if (!v) return;
    
    $('#bo-plate').text(v.plate.toUpperCase());
    
    const date = new Date(v.stolenDate * 1000);
    $('#bo-date').text(date.toLocaleString('pt-BR'));
    
    $('#bo-viewer').fadeIn(200);
}

// ============================================================
// LÓGICA DE PROPRIEDADES
// ============================================================
function loadProperties() {
    nui('getProperties').then(data => {
        const list = $('#property-list');
        list.empty();
        
        currentProperties = data || [];
        
        if (data && data.length > 0) {
            data.forEach((p, index) => {
                
                let statusHtml = "";
                if (p.expired) {
                    statusHtml = `<span class="status-badge status-bad">IPTU ATRASADO</span>`;
                } else {
                    statusHtml = `<span class="status-badge status-ok">IPTU EM DIA</span>`;
                }

                let expiredClass = "";
                if (p.expired) {
                    expiredClass = "expired";
                }
                
                list.append(`
                    <div class="property-card ${expiredClass}">
                        <div class="card-header">
                            <div>
                                <div class="card-title">${p.name.toUpperCase()}</div>
                                <div class="card-subtitle">TIPO: ${p.type}</div>
                            </div>
                            ${statusHtml}
                        </div>
                        
                        <div class="card-details">
                            <p><strong>IPTU:</strong> R$ ${p.taxAmount} (${p.days} dias)</p>
                        </div>
                        
                        <div style="display:flex; flex-direction: column; gap: 8px; margin-top: 10px;">
                            <button class="btn-action btn-expand-prop" data-index="${index}">Ver Certidão / Escritura</button>
                        </div>
                    </div>
                `);
            });
            
            $('.btn-expand-prop').click(function() { 
                openEscritura($(this).data('index')); 
            });

        } else {
            list.html('<div class="empty-state">Nenhum imóvel encontrado.</div>');
        }
        
        switchScreen('screen-properties');
    });
}

function openEscritura(index) {
    const p = currentProperties[index];
    if (!p) return;
    
    $('#escritura-name').text((p.name || '...').toUpperCase());
    $('#escritura-type').text((p.type || '...').toUpperCase());
    
    let valorVenal = p.taxAmount * 150;
    $('#escritura-value').text('R$ ' + valorVenal.toLocaleString('pt-BR'));
    
    if (p.expired) {
        $('#escritura-status').text('SITUAÇÃO IRREGULAR - DÉBITO PENDENTE');
        $('#escritura-status').css('background', '#cc0000');
    } else {
        $('#escritura-status').text('SITUAÇÃO REGULAR');
        $('#escritura-status').css('background', '#8d6e63');
    }

    $('#escritura-viewer').fadeIn(200);
}

// ============================================================
// FECHAR OVERLAYS
// ============================================================
$('.btn-close-overlay, .crlv-overlay').click(function(e) {
    if (e.target === this) {
        $(this).closest('.crlv-overlay').fadeOut(200);
    }
});