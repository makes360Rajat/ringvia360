import React, { useState } from 'react';
import {
  FileText,
  Edit3,
  Save,
  RotateCcw,
  RefreshCw,
  ChevronDown,
  ChevronUp,
  Database,
  CheckCircle2,
  AlertTriangle,
  Plus,
  Trash2,
  Globe
} from 'lucide-react';
import { useApp } from '../context/AppContext';
import type { SitePageSection } from '../types';

const PAGE_LABELS: Record<string, string> = {
  home: '🏠 Home Page',
  features: '⚡ Features Page',
  pricing: '💰 Pricing Page',
  activities: '📞 Activities / Feed',
  analytics: '📊 Analytics',
  crm_sync: '🔗 CRM Sync',
  dashboard: '🎯 Dashboard',
  leaderboard: '🏆 Leaderboard'
};

export default function ContentEditorPanel() {
  const { sitePages, fetchPageContent, savePageSection, deletePageSection, resetDefaultPageContent, getPageSection, dbEngine } = useApp();

  const [activePageKey, setActivePageKey] = useState<string>('home');
  const [activeSectionKey, setActiveSectionKey] = useState<string | null>(null);
  const [editedSection, setEditedSection] = useState<Partial<SitePageSection> | null>(null);
  const [editedJson, setEditedJson] = useState<string>('');
  const [jsonError, setJsonError] = useState<string>('');
  const [isSaving, setIsSaving] = useState(false);
  const [saveResult, setSaveResult] = useState<{ ok: boolean; msg: string } | null>(null);
  const [isResetting, setIsResetting] = useState(false);
  const [expandedPages, setExpandedPages] = useState<Record<string, boolean>>({ home: true });
  const [newSectionKey, setNewSectionKey] = useState('');
  const [addingSection, setAddingSection] = useState(false);

  const pageKeys = Object.keys(sitePages).length > 0
    ? Object.keys(sitePages)
    : Object.keys(PAGE_LABELS);

  const handleSelectSection = (pageKey: string, sectionKey: string) => {
    const sec = getPageSection(pageKey, sectionKey);
    const fallback: Partial<SitePageSection> = {
      id: `sec-${pageKey}-${sectionKey}`,
      page_key: pageKey,
      page_title: PAGE_LABELS[pageKey]?.replace(/^[^\s]+ /, '') || pageKey,
      section_key: sectionKey,
      title: '',
      subtitle: '',
      body: '',
      media_url: '',
      data: {},
      order: 1,
      is_active: true
    };
    const target = sec || fallback;
    setActivePageKey(pageKey);
    setActiveSectionKey(sectionKey);
    setEditedSection({ ...target });
    setEditedJson(target.data ? JSON.stringify(target.data, null, 2) : '{}');
    setJsonError('');
    setSaveResult(null);
  };

  const handleJsonChange = (val: string) => {
    setEditedJson(val);
    try {
      JSON.parse(val);
      setJsonError('');
    } catch {
      setJsonError('Invalid JSON — fix before saving.');
    }
  };

  const handleSave = async () => {
    if (!editedSection || jsonError) return;
    let parsedData = editedSection.data;
    try {
      parsedData = JSON.parse(editedJson);
    } catch {
      setJsonError('Cannot save: fix JSON syntax errors first.');
      return;
    }
    setIsSaving(true);
    const ok = await savePageSection({ ...editedSection, data: parsedData });
    setIsSaving(false);
    setSaveResult({ ok, msg: ok ? '✓ Content saved to database!' : '✗ Failed to save. Check server.' });
    if (ok) await fetchPageContent();
    setTimeout(() => setSaveResult(null), 5000);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Delete this section from the database?')) return;
    const ok = await deletePageSection(id);
    if (ok) {
      setActiveSectionKey(null);
      setEditedSection(null);
      await fetchPageContent();
    }
  };

  const handleReset = async () => {
    if (!window.confirm('Reset ALL page content to factory defaults? This overwrites your custom content in the database.')) return;
    setIsResetting(true);
    const ok = await resetDefaultPageContent();
    setIsResetting(false);
    setSaveResult({ ok, msg: ok ? '✓ Default content restored to database.' : '✗ Reset failed.' });
    if (ok) await fetchPageContent();
    setTimeout(() => setSaveResult(null), 5000);
  };

  const handleAddSection = async () => {
    if (!newSectionKey.trim()) return;
    const key = newSectionKey.trim().toLowerCase().replace(/\s+/g, '_');
    handleSelectSection(activePageKey, key);
    setAddingSection(false);
    setNewSectionKey('');
  };

  const togglePage = (pk: string) => {
    setExpandedPages(prev => ({ ...prev, [pk]: !prev[pk] }));
  };

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '260px 1fr', gap: '1.25rem', minHeight: '600px' }}>
      {/* Left Sidebar */}
      <div style={{
        background: 'var(--bg-surface)',
        border: '1px solid var(--border-glass)',
        borderRadius: 'var(--radius-lg)',
        overflow: 'auto',
        padding: '0.75rem 0',
        display: 'flex',
        flexDirection: 'column'
      }}>
        <div style={{ padding: '0 1rem 0.75rem', borderBottom: '1px solid var(--border-subtle)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Database size={14} color="var(--primary)" />
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-main)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Site Content DB
            </span>
          </div>
          <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)', marginTop: '2px' }}>
            Engine: <span style={{ color: dbEngine === 'mysql' ? 'var(--accent-emerald)' : 'var(--accent-amber)', fontWeight: 600 }}>{(dbEngine || 'mysql').toUpperCase()}</span>
          </div>
        </div>

        <div style={{ flex: 1, overflow: 'auto' }}>
          {pageKeys.map(pk => {
            const sections = sitePages[pk]?.sections || {};
            const sectionKeys = Object.keys(sections);
            const isExpanded = expandedPages[pk] !== false;
            return (
              <div key={pk} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                <button
                  onClick={() => { togglePage(pk); setActivePageKey(pk); }}
                  style={{
                    width: '100%', display: 'flex', alignItems: 'center',
                    justifyContent: 'space-between', padding: '0.6rem 1rem',
                    background: activePageKey === pk && !activeSectionKey ? 'var(--primary-subtle)' : 'transparent',
                    border: 'none', cursor: 'pointer', color: 'var(--text-main)',
                    fontSize: '0.82rem', fontWeight: 600, textAlign: 'left'
                  }}
                >
                  <span>{PAGE_LABELS[pk] || pk}</span>
                  {isExpanded ? <ChevronUp size={13} color="var(--text-dim)" /> : <ChevronDown size={13} color="var(--text-dim)" />}
                </button>
                {isExpanded && (
                  <div>
                    {sectionKeys.map(sk => (
                      <button
                        key={sk}
                        onClick={() => handleSelectSection(pk, sk)}
                        style={{
                          width: '100%', display: 'flex', alignItems: 'center', gap: '0.4rem',
                          padding: '0.45rem 1rem 0.45rem 1.75rem',
                          background: activeSectionKey === sk && activePageKey === pk ? 'var(--primary-subtle)' : 'transparent',
                          border: 'none', cursor: 'pointer',
                          color: activeSectionKey === sk && activePageKey === pk ? 'var(--primary)' : 'var(--text-muted)',
                          fontSize: '0.78rem', textAlign: 'left',
                          borderLeft: activeSectionKey === sk && activePageKey === pk ? '2px solid var(--primary)' : '2px solid transparent'
                        }}
                      >
                        <FileText size={12} />
                        <span style={{ textTransform: 'capitalize' }}>{sk.replace(/_/g, ' ')}</span>
                      </button>
                    ))}
                    <button
                      onClick={() => { setActivePageKey(pk); setAddingSection(true); }}
                      style={{
                        width: '100%', display: 'flex', alignItems: 'center', gap: '0.35rem',
                        padding: '0.35rem 1rem 0.35rem 1.75rem', background: 'transparent',
                        border: 'none', cursor: 'pointer', color: 'var(--text-dim)', fontSize: '0.72rem'
                      }}
                    >
                      <Plus size={11} /> Add Section
                    </button>
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Add Section Input */}
        {addingSection && (
          <div style={{ padding: '0.6rem 0.75rem', borderTop: '1px solid var(--border-subtle)', background: 'var(--bg-surface-elevated)' }}>
            <p style={{ fontSize: '0.7rem', color: 'var(--text-dim)', marginBottom: '0.35rem' }}>
              New section for <strong>{PAGE_LABELS[activePageKey] || activePageKey}</strong>:
            </p>
            <input
              value={newSectionKey}
              onChange={e => setNewSectionKey(e.target.value)}
              placeholder="section_key"
              onKeyDown={e => e.key === 'Enter' && handleAddSection()}
              style={{
                width: '100%', padding: '0.35rem 0.5rem',
                background: 'var(--bg-input)', border: '1px solid var(--border-glass)',
                borderRadius: 'var(--radius-sm)', color: 'var(--text-main)', fontSize: '0.75rem', marginBottom: '0.35rem'
              }}
            />
            <div style={{ display: 'flex', gap: '0.4rem' }}>
              <button onClick={handleAddSection} className="btn-primary" style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}>Create</button>
              <button onClick={() => setAddingSection(false)} className="btn-ghost" style={{ fontSize: '0.7rem', padding: '0.25rem 0.5rem' }}>Cancel</button>
            </div>
          </div>
        )}

        {/* Bottom Actions */}
        <div style={{ padding: '0.6rem 0.75rem', borderTop: '1px solid var(--border-subtle)', display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
          <button
            onClick={() => fetchPageContent()}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.35rem',
              padding: '0.4rem', background: 'transparent', border: '1px solid var(--border-subtle)',
              borderRadius: 'var(--radius-md)', color: 'var(--text-dim)', fontSize: '0.72rem', cursor: 'pointer'
            }}
          >
            <RefreshCw size={12} /> Refresh from DB
          </button>
          <button
            onClick={handleReset}
            disabled={isResetting}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.35rem',
              padding: '0.4rem', background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.2)',
              borderRadius: 'var(--radius-md)', color: '#f87171', fontSize: '0.72rem', cursor: 'pointer', fontWeight: 600
            }}
          >
            <RotateCcw size={12} /> {isResetting ? 'Resetting…' : 'Reset Defaults'}
          </button>
        </div>
      </div>

      {/* Right Editor */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        {!editedSection ? (
          <div style={{
            flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
            background: 'var(--bg-surface)', border: '1px solid var(--border-glass)', borderRadius: 'var(--radius-lg)',
            gap: '0.75rem', padding: '3rem'
          }}>
            <Globe size={48} color="var(--border-glass)" />
            <p style={{ fontSize: '0.9rem', color: 'var(--text-dim)', textAlign: 'center' }}>Select a page section from the tree to edit its database content</p>
            <p style={{ fontSize: '0.75rem', color: 'var(--text-dim)', opacity: 0.6 }}>Content is saved to the <code style={{ color: 'var(--accent-cyan)' }}>site_pages</code> MySQL table</p>
          </div>
        ) : (
          <>
            {/* Editor Header */}
            <div style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              background: 'var(--bg-surface)', border: '1px solid var(--border-glass)',
              borderRadius: 'var(--radius-lg)', padding: '0.85rem 1.1rem'
            }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                  <Edit3 size={15} color="var(--primary)" />
                  <span style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-main)' }}>
                    {PAGE_LABELS[editedSection.page_key || ''] || editedSection.page_key} — {(editedSection.section_key || '').replace(/_/g, ' ').toUpperCase()}
                  </span>
                </div>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-dim)', marginTop: '2px' }}>
                  ID: <code style={{ color: 'var(--accent-cyan)', fontSize: '0.68rem' }}>{editedSection.id}</code>
                </div>
              </div>
              <div style={{ display: 'flex', gap: '0.5rem' }}>
                {editedSection.id && (
                  <button
                    onClick={() => handleDelete(editedSection.id!)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '0.3rem', padding: '0.4rem 0.75rem',
                      background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.25)',
                      borderRadius: 'var(--radius-md)', color: '#f87171', fontSize: '0.75rem', cursor: 'pointer'
                    }}
                  >
                    <Trash2 size={12} /> Delete
                  </button>
                )}
                <button
                  onClick={handleSave}
                  disabled={isSaving || !!jsonError}
                  className="btn-primary"
                  style={{ fontSize: '0.8rem', padding: '0.4rem 0.9rem', display: 'flex', alignItems: 'center', gap: '0.35rem' }}
                >
                  <Save size={13} />
                  {isSaving ? 'Saving…' : 'Save to DB'}
                </button>
              </div>
            </div>

            {/* Toast */}
            {saveResult && (
              <div style={{
                padding: '0.6rem 0.9rem', borderRadius: 'var(--radius-md)',
                background: saveResult.ok ? 'rgba(16,185,129,0.12)' : 'rgba(239,68,68,0.12)',
                border: `1px solid ${saveResult.ok ? 'rgba(16,185,129,0.3)' : 'rgba(239,68,68,0.3)'}`,
                color: saveResult.ok ? 'var(--accent-emerald)' : '#f87171',
                fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '0.4rem'
              }}>
                {saveResult.ok ? <CheckCircle2 size={14} /> : <AlertTriangle size={14} />}
                {saveResult.msg}
              </div>
            )}

            {/* Form */}
            <div style={{
              background: 'var(--bg-surface)', border: '1px solid var(--border-glass)',
              borderRadius: 'var(--radius-lg)', padding: '1.1rem',
              display: 'flex', flexDirection: 'column', gap: '0.9rem', overflow: 'auto'
            }}>
              {[
                { key: 'title', label: 'TITLE', col: 'content_title', rows: 1 },
                { key: 'subtitle', label: 'SUBTITLE', col: 'content_subtitle', rows: 2 },
                { key: 'body', label: 'BODY TEXT', col: 'body_text', rows: 3 },
                { key: 'media_url', label: 'MEDIA URL', col: 'media_url', rows: 1 }
              ].map(({ key, label, col, rows }) => (
                <div key={key}>
                  <label style={{ fontSize: '0.7rem', color: 'var(--text-dim)', display: 'block', marginBottom: '0.25rem', fontWeight: 700 }}>
                    {label} <span style={{ fontWeight: 400, opacity: 0.7 }}>({col})</span>
                  </label>
                  {rows === 1 ? (
                    <input
                      value={(editedSection as any)[key] || ''}
                      onChange={e => setEditedSection(prev => ({ ...prev, [key]: e.target.value }))}
                      style={{
                        width: '100%', padding: '0.55rem 0.7rem',
                        background: 'var(--bg-surface-elevated)', border: '1px solid var(--border-glass)',
                        borderRadius: 'var(--radius-md)', color: 'var(--text-main)', fontSize: '0.87rem',
                        fontFamily: key === 'media_url' ? 'var(--font-mono)' : 'inherit'
                      }}
                    />
                  ) : (
                    <textarea
                      value={(editedSection as any)[key] || ''}
                      onChange={e => setEditedSection(prev => ({ ...prev, [key]: e.target.value }))}
                      rows={rows}
                      style={{
                        width: '100%', padding: '0.55rem 0.7rem',
                        background: 'var(--bg-surface-elevated)', border: '1px solid var(--border-glass)',
                        borderRadius: 'var(--radius-md)', color: 'var(--text-main)', fontSize: '0.87rem',
                        resize: 'vertical', fontFamily: 'inherit'
                      }}
                    />
                  )}
                </div>
              ))}

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ fontSize: '0.7rem', color: 'var(--text-dim)', display: 'block', marginBottom: '0.25rem', fontWeight: 700 }}>DISPLAY ORDER</label>
                  <input
                    type="number"
                    value={editedSection.order ?? 1}
                    onChange={e => setEditedSection(prev => ({ ...prev, order: parseInt(e.target.value) || 1 }))}
                    style={{
                      width: '100%', padding: '0.55rem 0.7rem', background: 'var(--bg-surface-elevated)',
                      border: '1px solid var(--border-glass)', borderRadius: 'var(--radius-md)',
                      color: 'var(--text-main)', fontSize: '0.87rem'
                    }}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '0.7rem', color: 'var(--text-dim)', display: 'block', marginBottom: '0.25rem', fontWeight: 700 }}>STATUS</label>
                  <select
                    value={editedSection.is_active ? 'true' : 'false'}
                    onChange={e => setEditedSection(prev => ({ ...prev, is_active: e.target.value === 'true' }))}
                    style={{
                      width: '100%', padding: '0.55rem 0.7rem', background: 'var(--bg-surface-elevated)',
                      border: '1px solid var(--border-glass)', borderRadius: 'var(--radius-md)',
                      color: 'var(--text-main)', fontSize: '0.87rem'
                    }}
                  >
                    <option value="true">Active (Visible)</option>
                    <option value="false">Inactive (Hidden)</option>
                  </select>
                </div>
              </div>

              {/* JSON Data Editor */}
              <div>
                <label style={{ fontSize: '0.7rem', color: 'var(--text-dim)', display: 'block', marginBottom: '0.25rem', fontWeight: 700 }}>
                  STRUCTURED DATA (JSON) <span style={{ fontWeight: 400, opacity: 0.7 }}>(json_data column — plans, features, stats…)</span>
                </label>
                <textarea
                  value={editedJson}
                  onChange={e => handleJsonChange(e.target.value)}
                  rows={14}
                  spellCheck={false}
                  style={{
                    width: '100%', padding: '0.65rem 0.75rem',
                    background: 'var(--bg-surface-elevated)',
                    border: `1px solid ${jsonError ? 'rgba(239,68,68,0.5)' : 'var(--border-glass)'}`,
                    borderRadius: 'var(--radius-md)', color: 'var(--accent-cyan)', fontSize: '0.78rem',
                    resize: 'vertical', fontFamily: 'var(--font-mono)', lineHeight: 1.6
                  }}
                />
                {jsonError && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.3rem', color: '#f87171', fontSize: '0.72rem', marginTop: '0.25rem' }}>
                    <AlertTriangle size={12} /> {jsonError}
                  </div>
                )}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
