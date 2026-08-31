-- =====================================================================
--  CUESTA · CADASTRO DAS PESQUISAS POR SETOR
--  Rode DEPOIS de: schema + seed + policies + gestor + setores_demo.
--
--  Cria a pesquisa de cada setor (Padaria, Açougue, FLV, Caixa, Limpeza)
--  nas tabelas pergunta/opcao, e amarra o QR de cada setor à SUA pesquisa
--  (via cascata: o QR aponta direto pra pesquisa do próprio setor).
--
--  Pode rodar de novo à vontade: no começo ele limpa e recria.
-- =====================================================================

-- Função de apoio: cria uma pesquisa completa e devolve o id da versão.
create or replace function _cuesta_cria_pesquisa(
  p_emp uuid, p_titulo text, p_rating text, p_msg text, p_liked jsonb, p_gaps jsonb
) returns uuid language plpgsql as $$
declare v_pesq uuid; v_ver uuid; v_ql uuid; v_qg uuid; f jsonb; ord int;
begin
  insert into pesquisa (empresa_id, titulo) values (p_emp, p_titulo) returning id into v_pesq;
  insert into pesquisa_versao (pesquisa_id, versao, status, mensagem_final, publicada_em)
    values (v_pesq, 1, 'publicada', p_msg, now()) returning id into v_ver;

  insert into pergunta (pesquisa_versao_id, ordem, tipo, texto, obrigatoria)
    values (v_ver, 1, 'estrelas', p_rating, true);

  insert into pergunta (pesquisa_versao_id, ordem, tipo, texto, config)
    values (v_ver, 2, 'multipla', 'O que você mais gostou?', '{"chave":"liked"}') returning id into v_ql;
  ord := 0;
  for f in select * from jsonb_array_elements(p_liked) loop
    ord := ord + 1;
    insert into opcao (pergunta_id, ordem, texto, valor, icone, sentimento)
      values (v_ql, ord, f->>'texto', f->>'valor', f->>'icone', 'positivo');
  end loop;

  insert into pergunta (pesquisa_versao_id, ordem, tipo, texto, config)
    values (v_ver, 3, 'multipla', 'O que dava pra melhorar?', '{"chave":"gaps"}') returning id into v_qg;
  ord := 0;
  for f in select * from jsonb_array_elements(p_gaps) loop
    ord := ord + 1;
    insert into opcao (pergunta_id, ordem, texto, valor, icone, sentimento)
      values (v_qg, ord, f->>'texto', f->>'valor', f->>'icone', 'negativo');
  end loop;

  insert into pergunta (pesquisa_versao_id, ordem, tipo, texto)
    values (v_ver, 4, 'texto', 'Quer deixar um recado?');
  return v_ver;
end $$;

do $$
declare v_emp uuid; v_loja uuid; v_camp uuid; v_lmp uuid; v_ponto uuid; v_ver uuid;
begin
  select id into v_emp  from empresa where nome='Cuesta Supermercados';
  select id into v_loja from loja where empresa_id=v_emp and codigo='04';
  select id into v_camp from campanha where empresa_id=v_emp and ativa limit 1;

  -- ---- deixa idempotente: solta os QR e apaga versões anteriores destas pesquisas ----
  update qr_code set pesquisa_versao_id=null
    where slug in ('l04-pad-001','l04-aco-001','l04-flv-001','l04-cx-001','l04-lmp-001');
  delete from pesquisa where empresa_id=v_emp
    and titulo in ('Padaria','Açougue','Hortifrúti (FLV)','Caixa','Limpeza');

  -- ---- garante o setor + ponto + QR de LIMPEZA (não existia) ----
  select id into v_lmp from setor where empresa_id=v_emp and chave='limpeza';
  if v_lmp is null then
    insert into setor (empresa_id, chave, nome) values (v_emp,'limpeza','Limpeza') returning id into v_lmp;
  end if;
  select id into v_ponto from ponto where loja_id=v_loja and setor_id=v_lmp limit 1;
  if v_ponto is null then
    insert into ponto (loja_id, setor_id, tipo, nome) values (v_loja,v_lmp,'setor','Limpeza / Banheiros') returning id into v_ponto;
  end if;
  insert into qr_code (empresa_id, ponto_id, campanha_id, codigo, slug)
    values (v_emp, v_ponto, v_camp, 'QR-L04-LMP-001', 'l04-lmp-001') on conflict (slug) do nothing;

  -- ---- PADARIA ----
  v_ver := _cuesta_cria_pesquisa(v_emp,'Padaria','Como foi na Padaria hoje?','Foi um prazer ter você aqui!',
    '[{"valor":"pao","texto":"Pão fresquinho","icone":"bread"},{"valor":"variedade","texto":"Variedade (pães, doces, salgados)","icone":"grid"},{"valor":"atendimento","texto":"Atendimento no balcão","icone":"smile"},{"valor":"frescor","texto":"Frescor e aparência","icone":"sparkle"},{"valor":"ambiente","texto":"Cheiro e ambiente","icone":"heart"},{"valor":"precos","texto":"Preço justo","icone":"tag"}]'::jsonb,
    '[{"valor":"faltou","texto":"Faltou o que eu queria","icone":"search"},{"valor":"frescor","texto":"Não estava fresquinho","icone":"leaf"},{"valor":"fila","texto":"Demora no balcão","icone":"clock"},{"valor":"variedade","texto":"Pouca variedade","icone":"grid"},{"valor":"atendimento","texto":"Atendimento","icone":"smile"},{"valor":"precos","texto":"Preço alto","icone":"tag"}]'::jsonb);
  update qr_code set pesquisa_versao_id=v_ver where slug='l04-pad-001';

  -- ---- AÇOUGUE ----
  v_ver := _cuesta_cria_pesquisa(v_emp,'Açougue','Como foi no Açougue hoje?','Foi um prazer ter você aqui!',
    '[{"valor":"qualidade","texto":"Qualidade da carne","icone":"star"},{"valor":"atendimento","texto":"Atendimento e corte na hora","icone":"smile"},{"valor":"variedade","texto":"Variedade de cortes","icone":"grid"},{"valor":"frescor","texto":"Frescor","icone":"sparkle"},{"valor":"higiene","texto":"Higiene do balcão","icone":"sparkle"},{"valor":"precos","texto":"Preço justo","icone":"tag"}]'::jsonb,
    '[{"valor":"qualidade","texto":"Qualidade abaixo do esperado","icone":"star"},{"valor":"faltou","texto":"Faltou o corte que eu queria","icone":"search"},{"valor":"fila","texto":"Demora no atendimento","icone":"clock"},{"valor":"variedade","texto":"Pouca variedade","icone":"grid"},{"valor":"higiene","texto":"Higiene do balcão","icone":"sparkle"},{"valor":"precos","texto":"Preço alto","icone":"tag"}]'::jsonb);
  update qr_code set pesquisa_versao_id=v_ver where slug='l04-aco-001';

  -- ---- FLV (Hortifrúti) ----
  v_ver := _cuesta_cria_pesquisa(v_emp,'Hortifrúti (FLV)','Como estavam as frutas e verduras hoje?','Foi um prazer ter você aqui!',
    '[{"valor":"frescor","texto":"Frescor","icone":"leaf"},{"valor":"variedade","texto":"Variedade","icone":"grid"},{"valor":"aparencia","texto":"Boa aparência","icone":"sparkle"},{"valor":"precos","texto":"Preço justo","icone":"tag"},{"valor":"organizacao","texto":"Bem organizado","icone":"grid"}]'::jsonb,
    '[{"valor":"frescor","texto":"Não estavam frescos","icone":"leaf"},{"valor":"faltou","texto":"Faltou o que eu queria","icone":"search"},{"valor":"avariados","texto":"Produtos machucados / estragados","icone":"alert"},{"valor":"variedade","texto":"Pouca variedade","icone":"grid"},{"valor":"precos","texto":"Preço alto","icone":"tag"},{"valor":"organizacao","texto":"Bagunçado / mal organizado","icone":"grid"}]'::jsonb);
  update qr_code set pesquisa_versao_id=v_ver where slug='l04-flv-001';

  -- ---- CAIXA ----
  v_ver := _cuesta_cria_pesquisa(v_emp,'Caixa','Como foi na hora de passar no caixa?','Foi um prazer ter você aqui!',
    '[{"valor":"rapidez","texto":"Foi rápido","icone":"clock"},{"valor":"atendimento","texto":"Atendimento do operador","icone":"smile"},{"valor":"fila","texto":"Fila organizada","icone":"grid"},{"valor":"pagamento","texto":"Formas de pagamento","icone":"tag"},{"valor":"empacotamento","texto":"Empacotamento com cuidado","icone":"heart"}]'::jsonb,
    '[{"valor":"fila","texto":"Fila / demora","icone":"clock"},{"valor":"atendimento","texto":"Atendimento do operador","icone":"smile"},{"valor":"preco_errado","texto":"Erro no preço","icone":"tag"},{"valor":"pagamento","texto":"Problema no pagamento","icone":"alert"},{"valor":"empacotamento","texto":"Empacotamento","icone":"heart"}]'::jsonb);
  update qr_code set pesquisa_versao_id=v_ver where slug='l04-cx-001';

  -- ---- LIMPEZA ----
  v_ver := _cuesta_cria_pesquisa(v_emp,'Limpeza','A loja estava limpa e cuidada hoje?','Foi um prazer ter você aqui!',
    '[{"valor":"loja","texto":"Loja limpa","icone":"sparkle"},{"valor":"banheiro","texto":"Banheiro limpo","icone":"sparkle"},{"valor":"cheiro","texto":"Cheiro agradável","icone":"heart"},{"valor":"carrinho","texto":"Carrinhos limpos","icone":"grid"},{"valor":"corredores","texto":"Corredores limpos","icone":"grid"}]'::jsonb,
    '[{"valor":"banheiro","texto":"Banheiro sujo","icone":"alert"},{"valor":"chao","texto":"Chão ou corredores sujos","icone":"alert"},{"valor":"cheiro","texto":"Cheiro ruim","icone":"alert"},{"valor":"carrinho","texto":"Carrinho sujo","icone":"grid"},{"valor":"lixo","texto":"Lixo acumulado","icone":"alert"}]'::jsonb);
  update qr_code set pesquisa_versao_id=v_ver where slug='l04-lmp-001';

  raise notice 'Pesquisas de setor cadastradas e QRs amarrados.';
end $$;

-- limpa a função de apoio
drop function if exists _cuesta_cria_pesquisa(uuid,text,text,text,jsonb,jsonb);

-- confere o que ficou amarrado em cada QR:
select q.slug, q.codigo, p.titulo as pesquisa
from qr_code q
left join pesquisa_versao pv on pv.id = q.pesquisa_versao_id
left join pesquisa p on p.id = pv.pesquisa_id
where q.slug like 'l04-%'
order by q.slug;
