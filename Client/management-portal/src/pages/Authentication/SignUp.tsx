import {
  ArrowBackRounded,
  ArrowForwardRounded,
  BusinessRounded,
  CheckCircleRounded,
  CloudUploadOutlined,
  DirectionsCarRounded,
  LockOutlined,
} from '@mui/icons-material';
import {
  type ChangeEvent,
  type FormEvent,
  type InputHTMLAttributes,
  useMemo,
  useState,
} from 'react';
import { Link, useNavigate } from 'react-router-dom';

import {
  registerProvider,
  type ProviderSignupInput,
} from '../../api/authentication/authApi';

type TextFields = Omit<
  ProviderSignupInput,
  'license' | 'idCard' | 'hasAcceptedTerms'
>;

const initialValues: TextFields = {
  username: '',
  email: '',
  password: '',
  companyName: '',
  registrationNumber: '',
  contactName: '',
  contactPhone: '',
  contactEmail: '',
  street: '',
  city: '',
  state: '',
  country: '',
  postalCode: '',
  accountHolderName: '',
  accountNumber: '',
  bankName: '',
  iban: '',
  swiftCode: '',
};

const stepFields: Array<Array<keyof TextFields>> = [
  ['companyName', 'registrationNumber', 'username', 'email', 'password'],
  ['contactName', 'contactPhone', 'contactEmail', 'street', 'city', 'country'],
  ['accountHolderName', 'accountNumber', 'bankName'],
];

export default function SignUpPage() {
  const navigate = useNavigate();
  const [step, setStep] = useState(0);
  const [values, setValues] = useState(initialValues);
  const [license, setLicense] = useState<File | null>(null);
  const [idCard, setIdCard] = useState<File | null>(null);
  const [accepted, setAccepted] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const progress = useMemo(() => `${((step + 1) / 3) * 100}%`, [step]);

  function change(field: keyof TextFields) {
    return (event: ChangeEvent<HTMLInputElement>) => {
      setValues((current) => ({
        ...current,
        [field]: event.target.value,
      }));
      setError(null);
    };
  }

  function validateCurrentStep(): boolean {
    const requiredFields = stepFields[step] ?? [];
    const missing = requiredFields.some((field) => !values[field].trim());

    if (missing) {
      setError('Complete all required fields before continuing.');
      return false;
    }

    if (step === 0 && values.password.length < 8) {
      setError('Password must be at least 8 characters.');
      return false;
    }

    if (step === 2 && (!license || !idCard || !accepted)) {
      setError('Add both verification documents and accept the terms.');
      return false;
    }

    return true;
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (step < 2) {
      if (validateCurrentStep()) {
        setStep((current) => current + 1);
      }
      return;
    }

    if (!validateCurrentStep() || !license || !idCard) return;

    setSubmitting(true);
    setError(null);

    try {
      const message = await registerProvider({
        ...values,
        license,
        idCard,
        hasAcceptedTerms: accepted,
      });
      setSuccess(message);
    } catch (submitError) {
      setError(
        submitError instanceof Error
          ? submitError.message
          : 'Could not submit application.',
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (success) {
    return (
      <main className="signup-page success-page">
        <section className="signup-success-card">
          <span className="success-icon">
            <CheckCircleRounded />
          </span>
          <span className="eyebrow">APPLICATION RECEIVED</span>
          <h1>Thanks for applying.</h1>
          <p>
            {success} You can sign in after an administrator approves your
            provider account.
          </p>
          <button
            type="button"
            className="primary-button"
            onClick={() => navigate('/login')}
          >
            Back to sign in
          </button>
        </section>
      </main>
    );
  }

  const stepTitle = [
    'Company and account',
    'Contact and address',
    'Payout and verification',
  ][step];

  return (
    <main className="signup-page">
      <header className="signup-header">
        <Link className="signup-brand" to="/login">
          <span className="brand-mark">
            <DirectionsCarRounded />
          </span>
          DiamondCar
        </Link>
        <span>
          Already have an account? <Link to="/login">Sign in</Link>
        </span>
      </header>

      <section className="signup-layout">
        <aside className="signup-aside">
          <span className="eyebrow light">PROVIDER APPLICATION</span>
          <h1>Grow your rental business with DiamondCar.</h1>
          <p>
            Apply once, complete verification, and manage your fleet from a
            secure private workspace.
          </p>
          <div className="signup-benefit">
            <BusinessRounded />
            <span>
              <strong>Business-first tools</strong>
              <small>Fleet, booking and payout management</small>
            </span>
          </div>
          <div className="signup-benefit">
            <LockOutlined />
            <span>
              <strong>Reviewed access</strong>
              <small>Every provider application is verified</small>
            </span>
          </div>
        </aside>

        <form className="signup-card" onSubmit={submit} noValidate>
          <div className="signup-card-heading">
            <div>
              <span className="eyebrow">STEP {step + 1} OF 3</span>
              <h2>{stepTitle}</h2>
            </div>
            <span className="step-number">{step + 1}/3</span>
          </div>

          <div className="progress-track">
            <span style={{ width: progress }} />
          </div>

          {error && <div className="form-alert">{error}</div>}

          {step === 0 && (
            <div className="signup-grid">
              <Field label="Company name" value={values.companyName} onChange={change('companyName')} required />
              <Field label="Registration number" value={values.registrationNumber} onChange={change('registrationNumber')} required />
              <Field label="Username" value={values.username} onChange={change('username')} required />
              <Field label="Business email" type="email" value={values.email} onChange={change('email')} required />
              <Field className="wide-field" label="Password" type="password" autoComplete="new-password" hint="At least 8 characters" value={values.password} onChange={change('password')} required />
            </div>
          )}

          {step === 1 && (
            <div className="signup-grid">
              <Field label="Contact name" value={values.contactName} onChange={change('contactName')} required />
              <Field label="Phone number" type="tel" value={values.contactPhone} onChange={change('contactPhone')} required />
              <Field className="wide-field" label="Contact email" type="email" value={values.contactEmail} onChange={change('contactEmail')} required />
              <Field className="wide-field" label="Street address" value={values.street} onChange={change('street')} required />
              <Field label="City" value={values.city} onChange={change('city')} required />
              <Field label="State / region" value={values.state} onChange={change('state')} />
              <Field label="Country" value={values.country} onChange={change('country')} required />
              <Field label="Postal code" value={values.postalCode} onChange={change('postalCode')} />
            </div>
          )}

          {step === 2 && (
            <div className="signup-grid">
              <Field label="Account holder" value={values.accountHolderName} onChange={change('accountHolderName')} required />
              <Field label="Bank name" value={values.bankName} onChange={change('bankName')} required />
              <Field className="wide-field" label="Account number" value={values.accountNumber} onChange={change('accountNumber')} required />
              <Field label="IBAN" value={values.iban} onChange={change('iban')} />
              <Field label="SWIFT code" value={values.swiftCode} onChange={change('swiftCode')} />
              <FileField label="Business licence" file={license} onChange={setLicense} />
              <FileField label="Owner / representative ID" file={idCard} onChange={setIdCard} />
              <label className="terms-check wide-field">
                <input type="checkbox" checked={accepted} onChange={(event) => setAccepted(event.target.checked)} />
                <span>
                  I confirm these details are accurate and accept the provider
                  terms.
                </span>
              </label>
            </div>
          )}

          <div className="signup-actions">
            {step > 0 ? (
              <button
                type="button"
                className="secondary-button"
                onClick={() => {
                  setStep((current) => current - 1);
                  setError(null);
                }}
              >
                <ArrowBackRounded />
                Back
              </button>
            ) : (
              <span />
            )}

            <button
              type="submit"
              className="primary-button"
              disabled={submitting}
            >
              <span>
                {submitting
                  ? 'Submitting…'
                  : step === 2
                    ? 'Submit application'
                    : 'Continue'}
              </span>
              {!submitting && <ArrowForwardRounded />}
            </button>
          </div>
        </form>
      </section>
    </main>
  );
}

function Field({
  label,
  hint,
  className = '',
  required = false,
  ...input
}: InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  hint?: string;
}) {
  return (
    <label className={`signup-field ${className}`}>
      <span>
        {label}
        {required && <em>*</em>}
      </span>
      <input {...input} required={required} />
      {hint && <small>{hint}</small>}
    </label>
  );
}

function FileField({
  label,
  file,
  onChange,
}: {
  label: string;
  file: File | null;
  onChange: (file: File | null) => void;
}) {
  return (
    <label className="file-field">
      <input
        type="file"
        accept="image/jpeg,image/png,application/pdf"
        onChange={(event) => onChange(event.target.files?.[0] ?? null)}
      />
      <CloudUploadOutlined />
      <span>
        <strong>{label}</strong>
        <small>{file?.name || 'JPG, PNG or PDF'}</small>
      </span>
    </label>
  );
}
