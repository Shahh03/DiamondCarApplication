import { useEffect, useRef, useState, type FormEvent } from 'react';
import { ApartmentOutlined, CheckCircleOutlined, ErrorOutlined, PhotoCameraOutlined, RefreshRounded } from '@mui/icons-material';
import { Avatar, Button, Dialog, DialogActions, DialogContent, DialogTitle } from '@mui/material';
import { apiErrorMessage } from '../../../core/apiClient';
import { readSession, writeSession } from '../../../core/session';
import { getCompany, saveCompany, uploadCompanyPhoto, type CompanyDetails, type CompanyForm } from '../../../api/provider/providerCompanyApi';
import './ProviderCompanyPage.css';

function toForm(company: CompanyDetails): CompanyForm {
  return {
    companyName: company.companyName || '',
    contactPerson: { name: company.contactPerson?.name || '', phoneNumber: company.contactPerson?.phoneNumber || '', email: company.contactPerson?.email || '' },
    address: { street: company.address?.street || '', city: company.address?.city || '', state: company.address?.state || '', country: company.address?.country || '', postalCode: company.address?.postalCode || '' },
  };
}
function syncSession(company: CompanyDetails) {
  const session = readSession();
  if (session?.user._id !== company._id) return;
  writeSession({ ...session, user: { ...session.user, companyName: company.companyName, profilePicture: company.profilePicture, status: company.status } });
}

export default function ProviderCompanyPage() {
  const providerId = readSession()?.user._id || '';
  const [company, setCompany] = useState<CompanyDetails | null>(null);
  const [form, setForm] = useState<CompanyForm | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [reload, setReload] = useState(0);
  const [photo, setPhoto] = useState<File | null>(null);
  const [preview, setPreview] = useState('');
  const [notice, setNotice] = useState<{ title: string; message: string; error: boolean } | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);
  const dirty = !!company && !!form && JSON.stringify(toForm(company)) !== JSON.stringify(form);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    if (!providerId) {
      setLoading(false);
      setNotice({ title: 'Session unavailable', message: 'Please sign in again to view your company.', error: true });
      return () => controller.abort();
    }
    getCompany(providerId, controller.signal).then((data) => {
      if (controller.signal.aborted) return;
      setCompany(data); setForm(toForm(data)); syncSession(data);
    }).catch((error: unknown) => {
      if (!controller.signal.aborted) setNotice({ title: 'Could not load company', message: apiErrorMessage(error, 'Please try again.'), error: true });
    }).finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [providerId, reload]);

  useEffect(() => {
    if (!photo) { setPreview(''); return; }
    const url = URL.createObjectURL(photo);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [photo]);

  useEffect(() => {
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    if (dirty || photo) window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty, photo]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!form || busy) return;
    setBusy(true);
    try {
      const data = await saveCompany(providerId, form);
      setCompany(data); setForm(toForm(data)); syncSession(data);
      setNotice({ title: 'Company updated', message: 'Your company details have been saved.', error: false });
    } catch (error) {
      setNotice({ title: 'Could not save changes', message: apiErrorMessage(error, 'Please try again.'), error: true });
    } finally { setBusy(false); }
  }
  async function savePhoto() {
    if (!photo || busy) return;
    setBusy(true);
    try {
      const data = await uploadCompanyPhoto(providerId, photo);
      setCompany(data); syncSession(data); setPhoto(null);
      if (fileInput.current) fileInput.current.value = '';
      setNotice({ title: 'Photo updated', message: 'Your company photo has been saved.', error: false });
    } catch (error) {
      setNotice({ title: 'Could not upload photo', message: apiErrorMessage(error, 'Please try again.'), error: true });
    } finally { setBusy(false); }
  }
  const contact = (key: keyof CompanyForm['contactPerson'], value: string) =>
    setForm((current) => current ? { ...current, contactPerson: { ...current.contactPerson, [key]: value } } : current);
  const address = (key: keyof CompanyForm['address'], value: string) =>
    setForm((current) => current ? { ...current, address: { ...current.address, [key]: value } } : current);

  return (
    <main className="company-page" aria-busy={loading || busy}>
      <header className="company-page__heading">
        <div><h1>Company Profile</h1><p>Manage your company information and contact details.</p></div>
        <button className="company-page__secondary" disabled={loading || busy || dirty || !!photo}
          onClick={() => setReload((value) => value + 1)}><RefreshRounded fontSize="small" /> Refresh</button>
      </header>
      {loading ? <div className="company-page__empty" role="status">Loading company information…</div>
        : !company || !form ? <div className="company-page__empty">Company information could not be loaded. Use Refresh to try again.</div>
        : <div className="company-page__layout">
          <aside className="company-page__sidebar">
            <section className="company-page__card company-page__identity">
              <Avatar src={preview || company.profilePicture} alt={company.companyName} sx={{ width: 100, height: 100, fontSize: 36, bgcolor: '#2563eb', margin: '0 auto 18px' }}>
                {company.companyName?.charAt(0).toUpperCase() || <ApartmentOutlined />}
              </Avatar>
              <h2>{company.companyName}</h2>
              <p>{[company.address?.city, company.address?.country].filter(Boolean).join(', ') || 'Company location'}</p>
              <span className={'company-page__badge company-page__badge--' + (company.status || 'unknown').toLowerCase()}>
                {company.status === 'Accepted' ? 'Approved' : company.status || 'Status unavailable'}
              </span>
              <div className="company-page__photo">
                <input ref={fileInput} id="company-photo" type="file" accept="image/jpeg,image/png,image/webp" disabled={busy}
                  onChange={(event) => {
                    const file = event.target.files?.[0];
                    if (!file) return;
                    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 10 * 1024 * 1024) {
                      setNotice({ title: 'Choose another image', message: 'Use a JPG, PNG or WebP image smaller than 10 MB.', error: true });
                      event.target.value = ''; return;
                    }
                    setPhoto(file);
                  }} />
                <button type="button" className="company-page__secondary" disabled={busy} onClick={() => fileInput.current?.click()}>
                  <PhotoCameraOutlined fontSize="small" /> Change photo
                </button>
                <small>JPG, PNG or WebP · Up to 10 MB</small>
                {photo && <><small>{photo.name} — preview only</small>
                  <button type="button" className="company-page__primary" disabled={busy} onClick={() => void savePhoto()}>{busy ? 'Saving…' : 'Save photo'}</button>
                  <button type="button" className="company-page__secondary" disabled={busy} onClick={() => { setPhoto(null); if (fileInput.current) fileInput.current.value = ''; }}>Cancel photo</button></>}
              </div>
            </section>
            <section className="company-page__card">
              <h2>Account information</h2>
              <dl>
                <dt>Registration number</dt><dd>{company.registrationNumber || 'Not provided'}</dd>
                <dt>Verification</dt><dd>{company.isVerified ? 'Verified' : 'Not verified'}</dd>
                <dt>Account email</dt><dd>{company.email || 'Not provided'}</dd>
                <dt>Username</dt><dd>{company.username || 'Not provided'}</dd>
                <dt>Currency</dt><dd>{company.currency || 'Not provided'}</dd>
              </dl>
              <p className="company-page__hint">These account details are read-only here. Approval and verification are managed by an administrator.</p>
            </section>
          </aside>
          <form onSubmit={(event) => void submit(event)}>
            <fieldset disabled={busy} className="company-page__fieldset">
              <section className="company-page__card">
                <h2>Company details</h2><p className="company-page__hint">Keep your company name up to date. Required fields are marked *.</p>
                <label className="company-page__field">Company name *<input required maxLength={150} value={form.companyName} onChange={(event) => setForm({ ...form, companyName: event.target.value })} /></label>
              </section>
              <section className="company-page__card">
                <h2>Contact person</h2><p className="company-page__hint">The person renters can contact about their bookings.</p>
                <div className="company-page__fields">
                  <label className="company-page__field">Full name *<input required maxLength={150} autoComplete="name" value={form.contactPerson.name} onChange={(event) => contact('name', event.target.value)} /></label>
                  <label className="company-page__field">Phone number *<input required type="tel" maxLength={40} autoComplete="tel" value={form.contactPerson.phoneNumber} onChange={(event) => contact('phoneNumber', event.target.value)} /></label>
                  <label className="company-page__field company-page__wide">Contact email *<input required type="email" maxLength={254} autoComplete="email" value={form.contactPerson.email} onChange={(event) => contact('email', event.target.value)} /><small>This does not change your sign-in email.</small></label>
                </div>
              </section>
              <section className="company-page__card">
                <h2>Company address</h2>
                <div className="company-page__fields">
                  <label className="company-page__field company-page__wide">Street address<input maxLength={200} autoComplete="street-address" value={form.address.street} onChange={(event) => address('street', event.target.value)} /></label>
                  <label className="company-page__field">City *<input required maxLength={100} autoComplete="address-level2" value={form.address.city} onChange={(event) => address('city', event.target.value)} /></label>
                  <label className="company-page__field">State / region<input maxLength={100} autoComplete="address-level1" value={form.address.state} onChange={(event) => address('state', event.target.value)} /></label>
                  <label className="company-page__field">Country *<input required maxLength={100} autoComplete="country-name" value={form.address.country} onChange={(event) => address('country', event.target.value)} /></label>
                  <label className="company-page__field">Postal code<input maxLength={30} autoComplete="postal-code" value={form.address.postalCode} onChange={(event) => address('postalCode', event.target.value)} /></label>
                </div>
              </section>
              <footer className="company-page__footer">
                <span role="status">{busy ? 'Saving…' : dirty ? 'You have unsaved changes.' : 'Your details are up to date.'}</span>
                <button type="button" className="company-page__secondary" disabled={!dirty} onClick={() => setForm(toForm(company))}>Discard changes</button>
                <button type="submit" className="company-page__primary" disabled={!dirty}>{busy ? 'Saving…' : 'Save changes'}</button>
              </footer>
            </fieldset>
          </form>
        </div>}
      <Dialog open={!!notice} onClose={() => setNotice(null)} aria-labelledby="company-notice-title" aria-describedby="company-notice-message" maxWidth="xs" fullWidth>
        <DialogTitle id="company-notice-title" sx={{ textAlign: 'center', pt: 4 }}>
          {notice?.error ? <ErrorOutlined sx={{ display: 'block', margin: '0 auto 12px', fontSize: 48, color: 'error.main' }} />
            : <CheckCircleOutlined sx={{ display: 'block', margin: '0 auto 12px', fontSize: 48, color: 'success.main' }} />}
          {notice?.title}
        </DialogTitle>
        <DialogContent id="company-notice-message" sx={{ textAlign: 'center' }}>{notice?.message}</DialogContent>
        <DialogActions sx={{ p: 3 }}><Button fullWidth variant="contained" color={notice?.error ? 'error' : 'primary'} onClick={() => setNotice(null)} autoFocus>OK</Button></DialogActions>
      </Dialog>
    </main>
  );
}
